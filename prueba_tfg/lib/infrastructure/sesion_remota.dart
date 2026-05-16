import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/entrada_leaderboard.dart';
import '../domain/alias_online.dart';
import '../domain/foundations_of_rome/foundations_of_rome.dart';

class SesionRemotaController extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Completer<void>? _joinCompleter;
  bool _modoRemotoActivo = false;
  bool _conectando = false;
  bool _conectado = false;
  int _versionSnapshot = 0;
  int _versionResumen = 0;
  int _versionPresencia = 0;
  int _versionLeaderboard = 0;
  int? _playerId;
  String? _playerAlias;
  String? _serverUrl;
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
  String? get ultimoError => _ultimoError;
  String? get ultimoErrorLeaderboard => _ultimoErrorLeaderboard;
  String? get alertaParticipantes => _alertaParticipantes;
  Juego? get ultimoSnapshot => _ultimoSnapshot;
  Map<String, dynamic>? get ultimoResumen => _ultimoResumen;
  Set<int> get jugadoresConectados => Set<int>.from(_jugadoresConectados);
  List<EntradaClasificacion> get leaderboard =>
      List<EntradaClasificacion>.unmodifiable(_leaderboard);
  bool get cargandoLeaderboard => _cargandoLeaderboard;

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

  Future<void> unirse(String url, {required String playerName}) async {
    final String normalizedUrl = _normalizarUrl(url.trim());
    if (normalizedUrl.isEmpty) {
      throw ArgumentError('La URL del servidor remoto no puede estar vacia.');
    }
    final String aliasNormalizado = AliasOnline.normalizar(playerName);
    final String? errorAlias = AliasOnline.mensajeError(aliasNormalizado);
    if (errorAlias != null) {
      throw ArgumentError(errorAlias);
    }

    await _cerrarCanal();
    _modoRemotoActivo = true;
    _conectando = true;
    _conectado = false;
    _playerId = null;
    _playerAlias = null;
    _serverUrl = normalizedUrl;
    _ultimoError = null;
    _ultimoErrorLeaderboard = null;
    _leaderboard = const <EntradaClasificacion>[];
    _cargandoLeaderboard = true;
    _versionLeaderboard = 0;
    _joinCompleter = Completer<void>();
    notifyListeners();

    try {
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

      _enviar(<String, dynamic>{
        'type': 'join',
        'playerName': aliasNormalizado,
      });

      await _joinCompleter!.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException(
            'El servidor no respondio al mensaje join en 8 segundos.',
          );
        },
      );
    } catch (error) {
      await _cerrarCanal();
      _modoRemotoActivo = false;
      _conectando = false;
      _conectado = false;
      _cargandoLeaderboard = false;
      _ultimoError = 'No se pudo abrir la sesion remota: $error';
      notifyListeners();
      rethrow;
    } finally {
      _joinCompleter = null;
    }
  }

  Future<void> cerrar() async {
    _joinCompleter = null;
    _modoRemotoActivo = false;
    _conectando = false;
    _conectado = false;
    _playerId = null;
    _playerAlias = null;
    _serverUrl = null;
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
    await _cerrarCanal();
    notifyListeners();
  }

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
    _enviar(<String, dynamic>{'type': 'getLeaderboard'});
  }

  Future<bool> enviarIngreso() {
    return _enviarAccion('income');
  }

  Future<bool> comprarParcela(int index) {
    return _enviarAccion('buyDeed', <String, dynamic>{'index': index});
  }

  Future<bool> construir({
    required String originCoord,
    required String templateId,
    required int rotationIndex,
    required bool isFromMonument,
  }) {
    return _enviarAccion('build', <String, dynamic>{
      'originCoord': originCoord,
      'templateId': templateId,
      'rotationIndex': rotationIndex,
      'isFromMonument': isFromMonument,
    });
  }

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
    _enviar(<String, dynamic>{
      'type': 'action',
      'action': action,
      'payload': payload,
    });
    return true;
  }

  void _manejarMensaje(dynamic rawMessage) {
    try {
      final Map<String, dynamic> message =
          (jsonDecode(rawMessage as String) as Map).cast<String, dynamic>();
      final String type = (message['type'] ?? '').toString();

      switch (type) {
        case 'joined':
          _conectando = false;
          _conectado = true;
          _playerId = message['playerId'] as int?;
          _playerAlias = message['playerName']?.toString();
          _joinCompleter?.complete();
          _aplicarPresencia(message);
          final dynamic gameJson = message['game'];
          if (gameJson is Map) {
            _aplicarSnapshot(gameJson.cast<String, dynamic>());
            return;
          }
          notifyListeners();
          return;
        case 'snapshot':
          final dynamic gameJson = message['game'];
          if (gameJson is Map) {
            _aplicarSnapshot(gameJson.cast<String, dynamic>());
          }
          return;
        case 'eraSummary':
          final dynamic summary = message['summary'];
          if (summary is Map) {
            _ultimoResumen = summary.cast<String, dynamic>();
            _versionResumen++;
            notifyListeners();
          }
          return;
        case 'presence':
          _aplicarPresencia(message);
          return;
        case 'leaderboard':
          final dynamic entries = message['entries'];
          final List<dynamic> entriesList = entries is List
              ? entries
              : const <dynamic>[];
          _leaderboard = entriesList
              .whereType<Map>()
              .map(
                (Map entry) =>
                    EntradaClasificacion.fromJson(entry.cast<String, dynamic>()),
              )
              .toList(growable: false);
          _cargandoLeaderboard = false;
          _ultimoErrorLeaderboard = null;
          _versionLeaderboard++;
          notifyListeners();
          return;
        case 'error':
          _conectando = false;
          _cargandoLeaderboard = false;
          _ultimoError = (message['message'] ?? 'Error remoto desconocido.')
              .toString();
          _ultimoErrorLeaderboard = _ultimoError;
          _completarJoinConError(StateError(_ultimoError!));
          notifyListeners();
          return;
      }
    } catch (error) {
      _completarJoinConError(error);
      _ultimoError = 'Mensaje remoto invalido: $error';
      notifyListeners();
    }
  }

  void _aplicarSnapshot(Map<String, dynamic> gameJson) {
    _ultimoSnapshot = Juego.fromJson(gameJson);
    _versionSnapshot++;
    notifyListeners();
  }

  void _aplicarPresencia(Map<String, dynamic> message) {
    final dynamic connectedIdsRaw = message['connectedPlayerIds'];
    final List<dynamic> connectedIdsList = connectedIdsRaw is List
        ? connectedIdsRaw
        : const <dynamic>[];
    _jugadoresConectados = connectedIdsList
        .map((dynamic value) => value as int)
        .toSet();

    final int expectedPlayerCount =
        message['expectedPlayerCount'] as int? ?? _jugadoresConectados.length;
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
      final String? event = message['event'] as String?;
      final String? playerName = message['playerName'] as String?;
      if (event == 'playerDisconnected' &&
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

  void _manejarErrorCanal(Object error) {
    _conectando = false;
    _conectado = false;
    _cargandoLeaderboard = false;
    _completarJoinConError(error);
    _ultimoError = 'La conexion remota fallo: $error';
    _ultimoErrorLeaderboard = _ultimoError;
    notifyListeners();
  }

  void _manejarCanalCerrado() {
    _conectando = false;
    _conectado = false;
    _cargandoLeaderboard = false;
    _ultimoError ??= 'La sesion remota se ha cerrado.';
    _ultimoErrorLeaderboard ??= _ultimoError;
    _completarJoinConError(StateError(_ultimoError!));
    notifyListeners();
  }

  void _completarJoinConError(Object error) {
    final Completer<void>? joinCompleter = _joinCompleter;
    if (joinCompleter == null || joinCompleter.isCompleted) {
      return;
    }
    joinCompleter.completeError(error);
  }

  void _enviar(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  Future<void> _cerrarCanal() async {
    final StreamSubscription<dynamic>? subscription = _subscription;
    final WebSocketChannel? channel = _channel;
    _subscription = null;
    _channel = null;

    await subscription?.cancel();
    await channel?.sink.close();
  }

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
      channel.sink.add(jsonEncode(<String, dynamic>{'type': 'getLeaderboard'}));

      final dynamic rawMessage = await channel.stream.first.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException(
            'El servidor no respondio al leaderboard en 8 segundos.',
          );
        },
      );

      final Map<String, dynamic> message =
          (jsonDecode(rawMessage as String) as Map).cast<String, dynamic>();
      final String type = (message['type'] ?? '').toString();

      if (type == 'error') {
        throw StateError(
          (message['message'] ?? 'Error remoto desconocido.').toString(),
        );
      }

      if (type != 'leaderboard') {
        throw StateError('Respuesta inesperada del servidor: $type');
      }

      final List<dynamic> entries =
          message['entries'] as List<dynamic>? ?? const <dynamic>[];
      return entries
          .whereType<Map>()
          .map(
            (Map entry) =>
                EntradaClasificacion.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false);
    } finally {
      await channel.sink.close();
    }
  }
}
