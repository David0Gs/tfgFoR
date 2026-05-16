import 'dart:convert';
import 'dart:io';

import 'package:prueba_tfg/domain/entrada_leaderboard.dart';
import 'package:prueba_tfg/domain/alias_online.dart';
import 'package:prueba_tfg/domain/foundations_of_rome/foundations_of_rome.dart';
import 'headless/ranking_global_factory.dart';
import 'headless/ranking_global_store.dart';

class _ClienteRemoto {
  _ClienteRemoto({
    required this.socket,
    required this.playerId,
    required this.playerName,
  });

  final WebSocket socket;
  final int playerId;
  String playerName;
}

Future<void> main(List<String> args) async {
  final Map<String, String> opciones = _parseArgs(args);
  final String host = opciones['host'] ?? '0.0.0.0';
  final int port = int.tryParse(opciones['port'] ?? '8080') ?? 8080;
  final int playerCount = int.tryParse(opciones['players'] ?? '2') ?? 2;
  final String dbSpec = (opciones['db'] ?? '').trim();

  if (playerCount < 2 || playerCount > 5) {
    stderr.writeln('El numero de jugadores debe estar entre 2 y 5.');
    exitCode = 64;
    return;
  }

  if (dbSpec.isEmpty) {
    stderr.writeln('Falta el parametro obligatorio --db.');
    _imprimirUso();
    exitCode = 64;
    return;
  }

  final RankingGlobalBackend backend;
  try {
    backend = await crearRankingGlobalDesdeDbSpec(dbSpec);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    _imprimirUso();
    exitCode = 64;
    return;
  } catch (error) {
    stderr.writeln('No se pudo inicializar la persistencia de ranking: $error');
    exitCode = 1;
    return;
  }

  final _ServidorHeadless servidor = _ServidorHeadless(
    playerCount,
    rankingGlobal: backend.store,
    descripcionRanking: backend.descripcion,
  );
  try {
    await servidor.start(host: host, port: port);
  } finally {
    await servidor.close();
  }
}

void _imprimirUso() {
  stderr.writeln(
    'Uso: dart run bin/for_headless_server.dart --db=<ruta_sqlite|postgres://...> [--host=0.0.0.0] [--port=8080] [--players=2]',
  );
}

Map<String, String> _parseArgs(List<String> args) {
  final Map<String, String> opciones = <String, String>{};
  for (int index = 0; index < args.length; index++) {
    final String arg = args[index];

    if (arg.startsWith('--') && arg.contains('=')) {
      final List<String> partes = arg.substring(2).split('=');
      if (partes.length != 2) {
        continue;
      }
      opciones[partes.first] = partes.last;
      continue;
    }

    if (arg.startsWith('--') && index + 1 < args.length) {
      final String key = arg.substring(2);
      final String nextArg = args[index + 1];
      if (key.isEmpty || nextArg.startsWith('-') || nextArg.contains('=')) {
        continue;
      }
      opciones[key] = nextArg;
      index++;
      continue;
    }

    if (arg.contains('=')) {
      final List<String> partes = arg.split('=');
      if (partes.length != 2 || partes.first.isEmpty) {
        continue;
      }
      opciones[partes.first] = partes.last;
    }
  }
  return opciones;
}

class _ServidorHeadless {
  _ServidorHeadless(
    int playerCount, {
    required RankingGlobalStore rankingGlobal,
    required String descripcionRanking,
  }) : _game = Juego(playerCount),
       _rankingGlobal = rankingGlobal,
       _descripcionRanking = descripcionRanking;

  final Juego _game;
  final RankingGlobalStore _rankingGlobal;
  final String _descripcionRanking;
  final Map<WebSocket, _ClienteRemoto> _clientesPorSocket =
      <WebSocket, _ClienteRemoto>{};
  HttpServer? _server;
  bool _rankingFinalPersistido = false;
  bool _cerrado = false;

  Future<void> start({required String host, required int port}) async {
    _server = await HttpServer.bind(host, port);
    stdout.writeln(
      'Servidor headless listo en ws://$host:$port para ${_game.numeroJugadores} jugadores.',
    );
    stdout.writeln('Ranking global: $_descripcionRanking');

    await for (final HttpRequest request in _server!) {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write('Foundations of Rome headless server')
          ..close();
        continue;
      }

      final WebSocket socket = await WebSocketTransformer.upgrade(request);
      _registrarSocket(socket);
    }
  }

  void _registrarSocket(WebSocket socket) {
    socket.listen(
      (dynamic data) {
        _manejarMensaje(socket, data);
      },
      onDone: () => _desconectar(socket),
      onError: (_) => _desconectar(socket),
      cancelOnError: true,
    );
  }

  Future<void> _manejarMensaje(WebSocket socket, dynamic rawData) async {
    try {
      final Map<String, dynamic> message =
          (jsonDecode(rawData as String) as Map).cast<String, dynamic>();
      final String type = (message['type'] ?? '').toString();

      switch (type) {
        case 'join':
          await _manejarJoin(socket, message);
          return;
        case 'getLeaderboard':
          await _manejarSolicitudLeaderboard(socket);
          return;
        case 'action':
          await _manejarAccion(socket, message);
          return;
        default:
          _enviarError(socket, 'Tipo de mensaje no soportado: $type');
      }
    } catch (error) {
      _enviarError(socket, 'Mensaje invalido: $error');
    }
  }

  Future<void> _manejarJoin(
    WebSocket socket,
    Map<String, dynamic> message,
  ) async {
    final _ClienteRemoto? existente = _clientesPorSocket[socket];
    if (existente != null) {
      _enviar(socket, _mensajeJoined(existente));
      _enviar(socket, await _mensajeLeaderboard());
      return;
    }

    final Set<int> ocupados = _clientesPorSocket.values
        .map((cliente) => cliente.playerId)
        .toSet();
    final int playerId = List<int>.generate(
      _game.numeroJugadores,
      (i) => i,
    ).firstWhere((id) => !ocupados.contains(id), orElse: () => -1);

    if (playerId < 0) {
      _enviarError(socket, 'La partida ya esta completa.');
      socket.close(WebSocketStatus.policyViolation, 'Partida completa');
      return;
    }

    final String playerName = AliasOnline.normalizar(
      (message['playerName'] ?? '').toString(),
    );
    final String? errorAlias = AliasOnline.mensajeError(
      playerName,
      aliasesOcupados: _clientesPorSocket.values.map(
        (_ClienteRemoto cliente) => cliente.playerName,
      ),
    );
    if (errorAlias != null) {
      _enviarError(socket, errorAlias);
      socket.close(WebSocketStatus.policyViolation, errorAlias);
      return;
    }

    _game.players[playerId].name = playerName;

    final _ClienteRemoto cliente = _ClienteRemoto(
      socket: socket,
      playerId: playerId,
      playerName: playerName,
    );
    _clientesPorSocket[socket] = cliente;

    stdout.writeln(
      'Jugador unido: ${cliente.playerName} (#${cliente.playerId + 1}).',
    );
    _enviar(socket, _mensajeJoined(cliente));
    _enviar(socket, await _mensajeLeaderboard());
    _broadcastSnapshot();
    _broadcastPresencia(
      event: 'playerJoined',
      playerId: cliente.playerId,
      playerName: cliente.playerName,
    );
  }

  Future<void> _manejarSolicitudLeaderboard(WebSocket socket) async {
    _enviar(socket, await _mensajeLeaderboard());
  }

  Future<void> _manejarAccion(
    WebSocket socket,
    Map<String, dynamic> message,
  ) async {
    final _ClienteRemoto? cliente = _clientesPorSocket[socket];
    if (cliente == null) {
      _enviarError(socket, 'Debes unirte antes de enviar acciones.');
      return;
    }

    if (cliente.playerId != _game.indiceJugadorActual) {
      _enviarError(socket, 'No es tu turno.');
      return;
    }

    final String action = (message['action'] ?? '').toString();
    final Map<String, dynamic> payload =
        ((message['payload'] as Map?) ?? <String, dynamic>{})
            .cast<String, dynamic>();

    bool resultado = false;
    switch (action) {
      case 'income':
        _game.accionIngresos();
        resultado = true;
        break;
      case 'buyDeed':
        try {
          resultado = _game.comprarParcela(payload['index'] as int? ?? -1);
        } on RuleError catch (error) {
          _enviarError(socket, error.message);
          return;
        }
        break;
      case 'build':
        try {
          resultado = _ejecutarConstruccionRemota(cliente, payload);
        } on RuleError catch (error) {
          _enviarError(socket, error.message);
          return;
        }
        break;
      default:
        _enviarError(socket, 'Accion no soportada: $action');
        return;
    }

    if (!resultado) {
      _enviarError(socket, 'La accion $action no pudo aplicarse.');
      return;
    }

    await _emitirResumenesPendientes();
    _broadcastSnapshot();
  }

  bool _ejecutarConstruccionRemota(
    _ClienteRemoto cliente,
    Map<String, dynamic> payload,
  ) {
    final String originCoord = (payload['originCoord'] ?? '').toString();
    final String templateId = (payload['templateId'] ?? '').toString();
    final int rotationIndex = payload['rotationIndex'] as int? ?? 0;
    final bool isFromMonument = payload['isFromMonument'] == true;

    final Edificio? template = buscarEdificioPorId(templateId);
    if (template == null) {
      throw RuleError('Edificio no encontrado: $templateId');
    }

    final int buildingIdx = isFromMonument
        ? _game.monumentosDisponibles.indexWhere(
            (building) => building.id == templateId,
          )
        : _game.players[cliente.playerId].availableBuildings.indexWhere(
            (building) => building.id == templateId,
          );
    if (buildingIdx < 0) {
      throw const RuleError('El edificio seleccionado ya no esta disponible.');
    }

    return _game.construir(
      originCoord,
      template,
      rotationIndex,
      buildingIdx,
      isFromMonument,
    );
  }

  Map<String, dynamic> _mensajeJoined(_ClienteRemoto cliente) {
    return <String, dynamic>{
      'type': 'joined',
      'playerId': cliente.playerId,
      'playerName': cliente.playerName,
      'game': _game.toJson(includePendingSummary: false),
    };
  }

  Future<void> _emitirResumenesPendientes() async {
    while (true) {
      final Map<String, dynamic>? resumen = _game.consumirResumenPendiente();
      if (resumen == null) {
        return;
      }

      await _registrarRankingFinalSiProcede(resumen);

      final Map<String, dynamic> mensaje = <String, dynamic>{
        'type': 'eraSummary',
        'summary': resumen,
      };
      for (final _ClienteRemoto cliente in _clientesPorSocket.values) {
        _enviar(cliente.socket, mensaje);
      }

      _game.confirmarResumenPendiente();
    }
  }

  Future<void> _registrarRankingFinalSiProcede(
    Map<String, dynamic> resumen,
  ) async {
    if (_rankingFinalPersistido || resumen['isFinal'] != true) {
      return;
    }

    for (final Jugador jugador in _game.players) {
      await _rankingGlobal.registrarPuntuacionMaxima(
        alias: jugador.name,
        puntuacion: jugador.glory,
      );
    }

    _rankingFinalPersistido = true;
    await _broadcastLeaderboard();
  }

  void _broadcastSnapshot() {
    final Map<String, dynamic> snapshot = <String, dynamic>{
      'type': 'snapshot',
      'game': _game.toJson(includePendingSummary: false),
    };
    for (final _ClienteRemoto cliente in _clientesPorSocket.values) {
      _enviar(cliente.socket, snapshot);
    }
  }

  void _broadcastPresencia({
    required String event,
    required int playerId,
    required String playerName,
  }) {
    if (_clientesPorSocket.isEmpty) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'type': 'presence',
      'event': event,
      'playerId': playerId,
      'playerName': playerName,
      'expectedPlayerCount': _game.numeroJugadores,
      'connectedPlayerIds':
          _clientesPorSocket.values.map((cliente) => cliente.playerId).toList()
            ..sort(),
    };

    for (final _ClienteRemoto cliente in _clientesPorSocket.values) {
      _enviar(cliente.socket, payload);
    }
  }

  Future<void> _broadcastLeaderboard() async {
    if (_clientesPorSocket.isEmpty) {
      return;
    }

    final Map<String, dynamic> mensaje = await _mensajeLeaderboard();
    for (final _ClienteRemoto cliente in _clientesPorSocket.values) {
      _enviar(cliente.socket, mensaje);
    }
  }

  Future<Map<String, dynamic>> _mensajeLeaderboard() async {
    return <String, dynamic>{
      'type': 'leaderboard',
      'entries': (await _rankingGlobal.cargarTop10())
          .map((EntradaClasificacion entrada) => entrada.toJson())
          .toList(growable: false),
    };
  }

  void _enviar(WebSocket socket, Map<String, dynamic> payload) {
    socket.add(jsonEncode(payload));
  }

  void _enviarError(WebSocket socket, String message) {
    _enviar(socket, <String, dynamic>{'type': 'error', 'message': message});
  }

  void _desconectar(WebSocket socket) {
    final _ClienteRemoto? cliente = _clientesPorSocket.remove(socket);
    if (cliente == null) {
      return;
    }
    stdout.writeln(
      'Jugador desconectado: ${cliente.playerName} (#${cliente.playerId + 1}).',
    );
    _broadcastPresencia(
      event: 'playerDisconnected',
      playerId: cliente.playerId,
      playerName: cliente.playerName,
    );
  }

  Future<void> close() async {
    if (_cerrado) {
      return;
    }
    _cerrado = true;
    await _server?.close(force: true);
    await _rankingGlobal.close();
  }
}
