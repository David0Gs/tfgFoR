// Controlador de una sesion multijugador remota. Mantiene el WebSocket con el
// backend, traduce mensajes del protocolo a estado Flutter y envia acciones del
// jugador esperando confirmacion del servidor.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:for_core/core.dart';
import 'package:for_core/protocol.dart';
import 'remote_session_store.dart';

/// Gestiona la conexion remota de una partida online.
class SesionRemotaController extends ChangeNotifier {
  SesionRemotaController({RemoteSessionStore? sessionStore})
    : _sessionStore = sessionStore ?? RemoteSessionStore();

  final RemoteSessionStore _sessionStore;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Completer<void>? _joinCompleter;
  final Map<String, Completer<bool>> _accionesPendientes =
      <String, Completer<bool>>{};
  static final Map<String, _SesionRemotaRecordada> _sesionesRecordadas =
      <String, _SesionRemotaRecordada>{};
  bool _modoRemotoActivo = false;
  bool _conectando = false;
  bool _conectado = false;
  bool _cierrePorFinalizacionRemota = false;
  int _versionSnapshot = 0;
  int _versionResumen = 0;
  int _versionPresencia = 0;
  int _versionLeaderboard = 0;
  int _nextRequestId = 1;
  int? _playerId;
  String? _playerAlias;
  String? _serverUrl;
  String? _gameId;
  String? _roomAlias;
  String? _sessionToken;
  String? _ultimoError;
  String? _ultimoErrorLeaderboard;
  String? _alertaParticipantes;
  Juego? _ultimoSnapshot;
  Map<String, dynamic>? _ultimoResumen;
  Set<int> _jugadoresConectados = <int>{};
  List<EntradaClasificacion> _leaderboard = const <EntradaClasificacion>[];
  bool _cargandoLeaderboard = false;

  bool get modoRemotoActivo => _modoRemotoActivo;
  bool get conectando => _conectando;
  bool get conectado => _conectado;
  int get versionSnapshot => _versionSnapshot;
  int get versionResumen => _versionResumen;
  int get versionPresencia => _versionPresencia;
  int get versionLeaderboard => _versionLeaderboard;
  int? get playerId => _playerId;
  String? get playerAlias => _playerAlias;
  String? get serverUrl => _serverUrl;
  String? get gameId => _gameId;
  String? get roomAlias => _roomAlias;
  String? get sessionToken => _sessionToken;
  String? get ultimoError => _ultimoError;
  String? get ultimoErrorLeaderboard => _ultimoErrorLeaderboard;
  String? get alertaParticipantes => _alertaParticipantes;
  Juego? get ultimoSnapshot => _ultimoSnapshot;
  Map<String, dynamic>? get ultimoResumen => _ultimoResumen;
  Set<int> get jugadoresConectados => Set<int>.from(_jugadoresConectados);
  List<EntradaClasificacion> get leaderboard =>
      List<EntradaClasificacion>.unmodifiable(_leaderboard);
  bool get cargandoLeaderboard => _cargandoLeaderboard;

  /// URL publica sugerida para conectar con el backend desplegado.
  static String get urlServidorLocalPorDefecto {
    return 'wss://api.fortfg.es';
  }

  /// Lee la URL inicial del servidor desde la query del navegador si existe.
  static String? leerUrlInicialDesdeNavegador() {
    if (!kIsWeb) {
      return null;
    }

    final Uri uri = Uri.base;
    final String? rawUrl =
        uri.queryParameters['server'] ?? uri.queryParameters['ws'];
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return null;
    }

    return _normalizarUrl(rawUrl.trim());
  }

  /// Lee el alias inicial del jugador desde la query del navegador si existe.
  static String? leerAliasInicialDesdeNavegador() {
    if (!kIsWeb) {
      return null;
    }

    final String? rawAlias = Uri.base.queryParameters['alias'];
    if (rawAlias == null || rawAlias.trim().isEmpty) {
      return null;
    }

    final String alias = AliasOnline.normalizar(rawAlias);
    return AliasOnline.esValido(alias) ? alias : null;
  }

  /// Abre una sesion remota creando sala o uniendose a una sala existente.
  Future<void> unirse(
    String url, {
    required String playerName,
    String? roomAlias,
    bool createRoom = false,
    int? players,
  }) async {
    final String normalizedUrl = _urlParaSala(
      _normalizarUrl(url.trim()),
      roomAlias,
    );
    if (normalizedUrl.isEmpty) {
      throw ArgumentError('La URL del servidor remoto no puede estar vacia.');
    }
    final String aliasNormalizado = AliasOnline.normalizar(playerName);
    final String? errorAlias = AliasOnline.mensajeError(aliasNormalizado);
    if (errorAlias != null) {
      throw ArgumentError(errorAlias);
    }

    final _SesionRemotaRecordada? sesionRecordada =
        _buscarSesionRecordada(normalizedUrl, aliasNormalizado) ??
        await _cargarSesionRecordada(normalizedUrl, aliasNormalizado);
    final String clientId = await _obtenerClientId();
    final String? accessToken = _leerAccessToken(normalizedUrl);

    _completarAccionesPendientes(false);
    await _cerrarCanal();
    _modoRemotoActivo = true;
    _conectando = true;
    _conectado = false;
    _cierrePorFinalizacionRemota = false;
    _playerId = null;
    _playerAlias = aliasNormalizado;
    _serverUrl = normalizedUrl;
    _gameId = sesionRecordada?.gameId;
    _roomAlias = roomAlias?.trim().toUpperCase();
    _sessionToken = sesionRecordada?.sessionToken;
    _ultimoError = null;
    _ultimoErrorLeaderboard = null;
    _leaderboard = const <EntradaClasificacion>[];
    _cargandoLeaderboard = true;
    _versionLeaderboard = 0;
    _joinCompleter = Completer<void>();
    notifyListeners();

    try {
      await _conectarYEnviarJoin(
        normalizedUrl,
        playerName: aliasNormalizado,
        roomAlias: roomAlias,
        createRoom: createRoom,
        players: players,
        accessToken: accessToken,
        clientId: clientId,
      );
    } catch (error) {
      if (sesionRecordada != null && _esErrorSesionCaducada(error)) {
        _olvidarSesionRecordada(normalizedUrl, aliasNormalizado);
        await _cerrarCanal();
        _conectando = true;
        _conectado = false;
        _gameId = null;
        _sessionToken = null;
        _ultimoError = null;
        _ultimoErrorLeaderboard = null;
        _joinCompleter = Completer<void>();
        notifyListeners();
        try {
          await _conectarYEnviarJoin(
            normalizedUrl,
            playerName: aliasNormalizado,
            roomAlias: roomAlias,
            createRoom: createRoom,
            players: players,
            accessToken: accessToken,
            clientId: clientId,
          );
          return;
        } catch (retryError) {
          await _marcarFalloUnionRemota(retryError);
          rethrow;
        }
      }
      await _marcarFalloUnionRemota(error);
      rethrow;
    } finally {
      _joinCompleter = null;
    }
  }

  /// Cierra la sesion remota y limpia el estado observable del controlador.
  Future<void> cerrar() async {
    _joinCompleter = null;
    _modoRemotoActivo = false;
    _conectando = false;
    _conectado = false;
    _cierrePorFinalizacionRemota = false;
    _playerId = null;
    _playerAlias = null;
    _serverUrl = null;
    _gameId = null;
    _roomAlias = null;
    _sessionToken = null;
    _ultimoError = null;
    _ultimoErrorLeaderboard = null;
    _alertaParticipantes = null;
    _ultimoSnapshot = null;
    _versionSnapshot = 0;
    _ultimoResumen = null;
    _versionResumen = 0;
    _jugadoresConectados = <int>{};
    _versionPresencia = 0;
    _leaderboard = const <EntradaClasificacion>[];
    _versionLeaderboard = 0;
    _cargandoLeaderboard = false;
    _completarAccionesPendientes(false);
    await _cerrarCanal();
    notifyListeners();
  }

  /// Solicita al servidor el leaderboard global.
  Future<void> solicitarLeaderboard() async {
    if (!_modoRemotoActivo || !_conectado || _channel == null) {
      _ultimoErrorLeaderboard = 'La sesion remota no esta conectada.';
      _cargandoLeaderboard = false;
      notifyListeners();
      return;
    }

    _ultimoErrorLeaderboard = null;
    _cargandoLeaderboard = true;
    notifyListeners();
    _enviar(const GetLeaderboardRequest().toJson());
  }

  /// Envia una accion de ingresos al servidor.
  Future<bool> enviarIngreso() {
    return _enviarAccion(TipoAccionRemota.income);
  }

  /// Envia una compra de parcela al servidor.
  Future<bool> comprarParcela(int index) {
    return _enviarAccion(TipoAccionRemota.buyDeed, <String, dynamic>{
      'index': index,
    });
  }

  /// Envia una construccion al servidor.
  Future<bool> construir({
    required String originCoord,
    required String templateId,
    required int rotationIndex,
    required bool isFromMonument,
  }) {
    return _enviarAccion(TipoAccionRemota.build, <String, dynamic>{
      'originCoord': originCoord,
      'templateId': templateId,
      'rotationIndex': rotationIndex,
      'isFromMonument': isFromMonument,
    });
  }

  /// Envia una accion remota y espera actionAccepted/actionRejected.
  Future<bool> _enviarAccion(
    String action, [
    Map<String, dynamic> payload = const <String, dynamic>{},
  ]) async {
    if (!_modoRemotoActivo || !_conectado || _channel == null) {
      _ultimoError = 'La sesion remota no esta conectada.';
      notifyListeners();
      return false;
    }

    _ultimoError = null;
    final String requestId = _crearRequestId(action);
    final Completer<bool> completer = Completer<bool>();
    _accionesPendientes[requestId] = completer;
    _enviar(
      ActionRequest(
        requestId: requestId,
        action: action,
        payload: payload,
      ).toJson(),
    );

    try {
      return await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          _accionesPendientes.remove(requestId);
          _ultimoError =
              'El servidor no confirmo la accion $action en 8 segundos.';
          notifyListeners();
          return false;
        },
      );
    } finally {
      _accionesPendientes.remove(requestId);
    }
  }

  /// Procesa un mensaje entrante del WebSocket.
  void _manejarMensaje(dynamic rawMessage) {
    try {
      final Map<String, dynamic> message = ProtocoloRemoto.decodificarJson(
        rawMessage as String,
      );
      final String type = ProtocoloRemoto.tipoDe(message);

      switch (type) {
        case TipoMensajeRemoto.joined:
          _conectando = false;
          _conectado = true;
          _playerId = message[CampoMensaje.playerId] as int?;
          _playerAlias = message[CampoMensaje.playerName]?.toString();
          _gameId = message[CampoMensaje.gameId]?.toString();
          _roomAlias = message[CampoMensaje.roomAlias]?.toString();
          _sessionToken = message[CampoMensaje.sessionToken]?.toString();
          _recordarSesionActual();
          _joinCompleter?.complete();
          _aplicarPresencia(message);
          final dynamic gameJson = message[CampoMensaje.game];
          if (gameJson is Map) {
            _aplicarSnapshot(gameJson.cast<String, dynamic>());
            return;
          }
          notifyListeners();
          return;
        case TipoMensajeRemoto.snapshot:
          final dynamic gameJson = message[CampoMensaje.game];
          if (gameJson is Map) {
            _aplicarSnapshot(gameJson.cast<String, dynamic>());
          }
          return;
        case TipoMensajeRemoto.eraSummary:
          final dynamic summary = message[CampoMensaje.summary];
          if (summary is Map) {
            _ultimoResumen = summary.cast<String, dynamic>();
            _versionResumen++;
            notifyListeners();
          }
          return;
        case TipoMensajeRemoto.presence:
          _aplicarPresencia(message);
          return;
        case TipoMensajeRemoto.leaderboard:
          _leaderboard = LeaderboardMessage.fromJson(message).entries;
          _cargandoLeaderboard = false;
          _ultimoErrorLeaderboard = null;
          _versionLeaderboard++;
          notifyListeners();
          return;
        case TipoMensajeRemoto.actionAccepted:
          _resolverAccionPendiente(message, true);
          return;
        case TipoMensajeRemoto.actionRejected:
          _ultimoError =
              (message[CampoMensaje.message] ?? 'Accion remota rechazada.')
                  .toString();
          _resolverAccionPendiente(message, false);
          notifyListeners();
          return;
        case TipoMensajeRemoto.error:
          _conectando = false;
          _cargandoLeaderboard = false;
          final String errorMessage =
              (message[CampoMensaje.message] ?? 'Error remoto desconocido.')
                  .toString();
          if (_esMensajeFinalizacionRemota(errorMessage)) {
            _cierrePorFinalizacionRemota = true;
            _alertaParticipantes = errorMessage;
            _versionPresencia++;
            _ultimoError = null;
            _ultimoErrorLeaderboard = null;
          } else {
            _ultimoError = errorMessage;
            _ultimoErrorLeaderboard = _ultimoError;
          }
          _completarJoinConError(StateError(errorMessage));
          _completarAccionesPendientes(false);
          notifyListeners();
          return;
      }
    } catch (error) {
      _completarJoinConError(error);
      _ultimoError = 'Mensaje remoto invalido: $error';
      notifyListeners();
    }
  }

  /// Aplica un snapshot completo de partida recibido del servidor.
  void _aplicarSnapshot(Map<String, dynamic> gameJson) {
    _ultimoSnapshot = Juego.fromJson(gameJson);
    _versionSnapshot++;
    notifyListeners();
  }

  /// Actualiza la presencia de jugadores conectados a la sala.
  void _aplicarPresencia(Map<String, dynamic> message) {
    final dynamic connectedIdsRaw = message[CampoMensaje.connectedPlayerIds];
    final List<dynamic> connectedIdsList = connectedIdsRaw is List
        ? connectedIdsRaw
        : const <dynamic>[];
    _jugadoresConectados = connectedIdsList
        .map((dynamic value) => value as int)
        .toSet();

    final int expectedPlayerCount =
        message[CampoMensaje.expectedPlayerCount] as int? ??
        _jugadoresConectados.length;
    final List<int> missingIds = List<int>.generate(
      expectedPlayerCount,
      (int index) => index,
    ).where((int id) => !_jugadoresConectados.contains(id)).toList()..sort();

    if (missingIds.isEmpty) {
      _alertaParticipantes = null;
    } else {
      final String missingPlayers = missingIds
          .map((int id) => 'Jugador ${id + 1}')
          .join(', ');
      final String? event = message[CampoMensaje.event] as String?;
      final String? playerName = message[CampoMensaje.playerName] as String?;
      if (event == EventoPresenciaRemota.playerDisconnected &&
          playerName != null &&
          playerName.isNotEmpty) {
        _alertaParticipantes =
            '$playerName se ha desconectado. Faltan $missingPlayers. La partida remota puede quedarse bloqueada; cierra la sesion remota si no van a volver.';
      } else {
        _alertaParticipantes =
            'Faltan $missingPlayers en la partida remota. La partida puede quedarse bloqueada hasta que vuelvan a conectarse.';
      }
    }

    _versionPresencia++;
    notifyListeners();
  }

  /// Gestiona un error del canal WebSocket.
  void _manejarErrorCanal(Object error) {
    _conectando = false;
    _conectado = false;
    _cargandoLeaderboard = false;
    _completarJoinConError(error);
    _completarAccionesPendientes(false);
    _ultimoError = 'La conexion remota fallo: $error';
    _ultimoErrorLeaderboard = _ultimoError;
    notifyListeners();
  }

  /// Gestiona el cierre del canal WebSocket.
  void _manejarCanalCerrado() {
    _conectando = false;
    _conectado = false;
    _cargandoLeaderboard = false;
    if (!_cierrePorFinalizacionRemota) {
      _ultimoError ??= 'La sesion remota se ha cerrado.';
      _ultimoErrorLeaderboard ??= _ultimoError;
      _completarJoinConError(StateError(_ultimoError!));
    }
    _completarAccionesPendientes(false);
    notifyListeners();
  }

  /// Completa el join pendiente con error si aun estaba esperando respuesta.
  void _completarJoinConError(Object error) {
    final Completer<void>? joinCompleter = _joinCompleter;
    if (joinCompleter == null || joinCompleter.isCompleted) {
      return;
    }
    joinCompleter.completeError(error);
  }

  /// Resuelve la accion pendiente que corresponde al requestId recibido.
  void _resolverAccionPendiente(Map<String, dynamic> message, bool accepted) {
    final String requestId = (message[CampoMensaje.requestId] ?? '').toString();
    final Completer<bool>? completer = _accionesPendientes.remove(requestId);
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete(accepted);
  }

  /// Completa todas las acciones pendientes con el valor indicado.
  void _completarAccionesPendientes(bool value) {
    final List<Completer<bool>> pendientes = _accionesPendientes.values.toList(
      growable: false,
    );
    _accionesPendientes.clear();
    for (final Completer<bool> completer in pendientes) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }
  }

  /// Crea un identificador unico para relacionar accion y respuesta.
  String _crearRequestId(String action) {
    final int requestNumber = _nextRequestId++;
    return '$action-$requestNumber';
  }

  /// Codifica y envia un payload por el WebSocket activo.
  void _enviar(Map<String, dynamic> payload) {
    _channel?.sink.add(ProtocoloRemoto.codificarJson(payload));
  }

  /// Abre el WebSocket y envia el mensaje join inicial.
  Future<void> _conectarYEnviarJoin(
    String normalizedUrl, {
    required String playerName,
    required String? roomAlias,
    required bool createRoom,
    required int? players,
    required String? accessToken,
    required String clientId,
  }) async {
    final WebSocketChannel channel = WebSocketChannel.connect(
      Uri.parse(normalizedUrl),
    );
    _channel = channel;
    _subscription = channel.stream.listen(
      _manejarMensaje,
      onError: _manejarErrorCanal,
      onDone: _manejarCanalCerrado,
      cancelOnError: true,
    );

    _enviar(
      JoinRequest(
        playerName: playerName,
        gameId: _gameId,
        roomAlias: roomAlias,
        createRoom: createRoom,
        players: players,
        sessionToken: _sessionToken,
        clientId: clientId,
        accessToken: accessToken,
      ).toJson(),
    );

    await _joinCompleter!.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        throw TimeoutException(
          'El servidor no respondio al mensaje join en 8 segundos.',
        );
      },
    );
  }

  /// Marca el intento de union como fallido y cierra recursos abiertos.
  Future<void> _marcarFalloUnionRemota(Object error) async {
    await _cerrarCanal();
    _modoRemotoActivo = false;
    _conectando = false;
    _conectado = false;
    _cargandoLeaderboard = false;
    _ultimoError = 'No se pudo abrir la sesion remota: $error';
    notifyListeners();
  }

  /// Guarda en memoria y almacenamiento local la sesion aceptada por servidor.
  void _recordarSesionActual() {
    final String? serverUrl = _serverUrl;
    final String? playerAlias = _playerAlias;
    final String? gameId = _gameId;
    final String? sessionToken = _sessionToken;
    if (serverUrl == null ||
        playerAlias == null ||
        gameId == null ||
        sessionToken == null ||
        sessionToken.isEmpty) {
      return;
    }

    _sesionesRecordadas[_claveSesionRecordada(serverUrl, playerAlias)] =
        _SesionRemotaRecordada(gameId: gameId, sessionToken: sessionToken);
    unawaited(
      _sessionStore.writeSession(
        _claveSesionRecordada(serverUrl, playerAlias),
        jsonEncode(<String, dynamic>{
          'gameId': gameId,
          'sessionToken': sessionToken,
        }),
      ),
    );
  }

  /// Busca una sesion recordada en memoria para servidor y alias.
  _SesionRemotaRecordada? _buscarSesionRecordada(
    String serverUrl,
    String alias,
  ) {
    return _sesionesRecordadas[_claveSesionRecordada(serverUrl, alias)];
  }

  /// Carga de almacenamiento local una sesion recordada para servidor y alias.
  Future<_SesionRemotaRecordada?> _cargarSesionRecordada(
    String serverUrl,
    String alias,
  ) async {
    final String key = _claveSesionRecordada(serverUrl, alias);
    final String? raw = await _sessionStore.readSession(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> json = (jsonDecode(raw) as Map)
          .cast<String, dynamic>();
      final String gameId = (json['gameId'] ?? '').toString();
      final String sessionToken = (json['sessionToken'] ?? '').toString();
      if (gameId.isEmpty || sessionToken.isEmpty) {
        return null;
      }
      final _SesionRemotaRecordada record = _SesionRemotaRecordada(
        gameId: gameId,
        sessionToken: sessionToken,
      );
      _sesionesRecordadas[key] = record;
      return record;
    } catch (_) {
      await _sessionStore.deleteSession(key);
      return null;
    }
  }

  /// Elimina una sesion recordada caducada.
  void _olvidarSesionRecordada(String serverUrl, String alias) {
    final String key = _claveSesionRecordada(serverUrl, alias);
    _sesionesRecordadas.remove(key);
    unawaited(_sessionStore.deleteSession(key));
  }

  /// Construye la clave interna usada para recordar una sesion remota.
  String _claveSesionRecordada(String serverUrl, String alias) {
    return '$serverUrl|$alias';
  }

  /// Detecta si el servidor rechazo un token porque la sesion ya no existe.
  bool _esErrorSesionCaducada(Object error) {
    return error.toString().contains('sesion ya no es valida');
  }

  /// Detecta errores que realmente indican finalizacion de partida remota.
  bool _esMensajeFinalizacionRemota(String message) {
    final String normalized = message.toLowerCase();
    return normalized.contains('partida remota') &&
        normalized.contains('finalizada');
  }

  /// Devuelve un identificador estable de cliente, creandolo si no existe.
  Future<String> _obtenerClientId() async {
    final String? storedClientId = await _sessionStore.readClientId();
    if (storedClientId != null && storedClientId.trim().isNotEmpty) {
      return storedClientId.trim();
    }
    final String clientId = _generarClientId();
    await _sessionStore.writeClientId(clientId);
    return clientId;
  }

  /// Genera un identificador aleatorio para este cliente.
  String _generarClientId() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Cierra suscripcion y WebSocket actuales.
  Future<void> _cerrarCanal() async {
    final StreamSubscription<dynamic>? subscription = _subscription;
    final WebSocketChannel? channel = _channel;
    _subscription = null;
    _channel = null;

    await subscription?.cancel();
    await channel?.sink.close();
  }

  /// Normaliza una URL aceptando esquemas http/https/ws/wss.
  static String _normalizarUrl(String rawUrl) {
    if (rawUrl.isEmpty) {
      return rawUrl;
    }

    final Uri uri = Uri.parse(rawUrl);
    if (!uri.hasScheme) {
      return 'ws://$rawUrl';
    }
    if (uri.scheme == 'http') {
      return uri.replace(scheme: 'ws').toString();
    }
    if (uri.scheme == 'https') {
      return uri.replace(scheme: 'wss').toString();
    }
    return uri.toString();
  }

  /// Construye la URL WebSocket concreta de una sala por alias.
  static String _urlParaSala(String normalizedUrl, String? rawRoomAlias) {
    final String roomAlias = rawRoomAlias?.trim().toUpperCase() ?? '';
    if (normalizedUrl.isEmpty || roomAlias.isEmpty) {
      return normalizedUrl;
    }
    final Uri uri = Uri.parse(normalizedUrl);
    return uri
        .replace(pathSegments: <String>['rooms', roomAlias, 'ws'])
        .toString();
  }

  /// Lee un token de acceso opcional desde la query de la URL.
  static String? _leerAccessToken(String normalizedUrl) {
    final Uri uri = Uri.parse(normalizedUrl);
    final String? token =
        uri.queryParameters['token'] ?? uri.queryParameters['accessToken'];
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    return token.trim();
  }

  /// Consulta el leaderboard remoto sin abrir una partida.
  static Future<List<EntradaClasificacion>> cargarLeaderboardRemoto(
    String url,
  ) async {
    final String normalizedUrl = _normalizarUrl(url.trim());
    if (normalizedUrl.isEmpty) {
      throw ArgumentError('La URL del servidor remoto no puede estar vacia.');
    }

    final WebSocketChannel channel = WebSocketChannel.connect(
      Uri.parse(normalizedUrl),
    );

    try {
      channel.sink.add(
        ProtocoloRemoto.codificarJson(const GetLeaderboardRequest().toJson()),
      );

      final dynamic rawMessage = await channel.stream.first.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException(
            'El servidor no respondio al leaderboard en 8 segundos.',
          );
        },
      );

      final Map<String, dynamic> message = ProtocoloRemoto.decodificarJson(
        rawMessage as String,
      );
      final String type = ProtocoloRemoto.tipoDe(message);

      if (type == TipoMensajeRemoto.error) {
        throw StateError(
          (message[CampoMensaje.message] ?? 'Error remoto desconocido.')
              .toString(),
        );
      }

      if (type != TipoMensajeRemoto.leaderboard) {
        throw StateError('Respuesta inesperada del servidor: $type');
      }

      return LeaderboardMessage.fromJson(message).entries;
    } finally {
      await channel.sink.close();
    }
  }
}

/// Registro minimo necesario para reconectar a una partida activa.
class _SesionRemotaRecordada {
  const _SesionRemotaRecordada({
    required this.gameId,
    required this.sessionToken,
  });

  final String gameId;
  final String sessionToken;
}
