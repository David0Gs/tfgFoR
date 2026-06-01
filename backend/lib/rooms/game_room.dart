// Sala remota de una partida. Contiene un Juego, sesiones de jugadores,
// WebSockets conectados, persistencia de snapshots/eventos y broadcast del
// protocolo remoto.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:async';

import 'package:for_core/core.dart';
import 'package:for_core/protocol.dart';
import '../persistence/partida_repository.dart';
import '../persistence/ranking_repository.dart';
import 'player_session.dart';

/// Resultado de una union a sala, indicando si fue reconexion.
class JoinResult {
  const JoinResult({required this.session, required this.reconnected});

  final PlayerSession session;
  final bool reconnected;
}

/// Sala multijugador con estado de partida y conexiones activas.
class GameRoom {
  /// Crea una sala nueva con una partida recien inicializada.
  GameRoom({
    required String id,
    String? roomAlias,
    required int playerCount,
    required RankingRepository rankingGlobal,
    required PartidaRepository partidaStore,
    Duration disconnectedGracePeriod = const Duration(minutes: 3),
    void Function(GameRoom room)? onSuspended,
  }) : this._(
         id: id,
         roomAlias: roomAlias,
         game: Juego(playerCount),
         rankingGlobal: rankingGlobal,
         partidaStore: partidaStore,
         disconnectedGracePeriod: disconnectedGracePeriod,
         onSuspended: onSuspended,
       );

  /// Restaura una sala desde un snapshot persistido.
  GameRoom.fromSnapshot({
    required String id,
    String? roomAlias,
    required Map<String, dynamic> snapshot,
    required RankingRepository rankingGlobal,
    required PartidaRepository partidaStore,
    Duration disconnectedGracePeriod = const Duration(minutes: 3),
    void Function(GameRoom room)? onSuspended,
  }) : this._(
         id: id,
         roomAlias: roomAlias,
         game: Juego.fromJson(snapshot),
         rankingGlobal: rankingGlobal,
         partidaStore: partidaStore,
         disconnectedGracePeriod: disconnectedGracePeriod,
         onSuspended: onSuspended,
       );

  GameRoom._({
    required this.id,
    required this.roomAlias,
    required this.game,
    required RankingRepository rankingGlobal,
    required PartidaRepository partidaStore,
    required Duration disconnectedGracePeriod,
    void Function(GameRoom room)? onSuspended,
  }) : _rankingGlobal = rankingGlobal,
       _partidaStore = partidaStore,
       _disconnectedGracePeriod = disconnectedGracePeriod,
       _onSuspended = onSuspended;

  final String id;
  final String? roomAlias;
  final Juego game;
  final RankingRepository _rankingGlobal;
  final PartidaRepository _partidaStore;
  final Duration _disconnectedGracePeriod;
  final void Function(GameRoom room)? _onSuspended;
  final Map<String, PlayerSession> _sessionsByToken = <String, PlayerSession>{};
  final Map<WebSocket, PlayerSession> _sessionsBySocket =
      <WebSocket, PlayerSession>{};
  final Map<String, Timer> _expirationTimersByToken = <String, Timer>{};

  bool _rankingFinalPersistido = false;
  bool _suspended = false;

  /// Numero de sockets conectados ahora mismo.
  int get connectedCount => _sessionsBySocket.length;

  /// Numero de plazas reservadas por token.
  int get sessionCount => _sessionsByToken.length;

  /// Indica si la sala se ha suspendido por desconexion prolongada.
  bool get suspended => _suspended;

  /// Sockets activos de la sala.
  Iterable<WebSocket> get connectedSockets => _sessionsBySocket.keys;

  /// Ids de jugadores conectados, ordenados.
  List<int> get connectedPlayerIds {
    return _sessionsBySocket.values.map((session) => session.playerId).toList()
      ..sort();
  }

  /// Resumen ligero de la sala para endpoints HTTP.
  Map<String, dynamic> toSummary() {
    return GameSummaryMessage(
      gameId: id,
      roomAlias: roomAlias,
      players: game.numeroJugadores,
      connectedPlayers: connectedCount,
      reservedPlayers: sessionCount,
      currentPlayerId: game.indiceJugadorActual,
      finished: game.partidaFinalizada,
    ).toJson();
  }

  /// Persiste la creacion inicial de la sala.
  Future<void> registrarCreacion() {
    return _partidaStore.registrarPartidaCreada(
      gameId: id,
      numeroJugadores: game.numeroJugadores,
      snapshot: game.toJson(includePendingSummary: false),
    );
  }

  /// Une o reconecta un jugador a la sala.
  Future<JoinResult> join({
    required WebSocket socket,
    required String playerName,
    required String clientId,
    String? sessionToken,
  }) async {
    if (_suspended) {
      throw const RuleError('La partida remota esta suspendida.');
    }

    final String alias = AliasOnline.normalizar(playerName);
    final String? errorAlias = AliasOnline.mensajeError(alias);
    if (errorAlias != null) {
      throw RuleError(errorAlias);
    }

    final String? requestedSessionToken = sessionToken?.trim().isEmpty == true
        ? null
        : sessionToken?.trim();
    final String normalizedClientId = clientId.trim();
    final PlayerSession? reconnecting = requestedSessionToken == null
        ? null
        : _sessionsByToken[requestedSessionToken];
    if (reconnecting != null) {
      if (reconnecting.clientId.isNotEmpty &&
          normalizedClientId.isNotEmpty &&
          reconnecting.clientId != normalizedClientId) {
        throw const RuleError(
          'La sesion pertenece a otro terminal. Vuelve a entrar desde el terminal original.',
        );
      }
      if (reconnecting.clientId.isEmpty && normalizedClientId.isNotEmpty) {
        reconnecting.clientId = normalizedClientId;
      }
      _replaceSocket(reconnecting, socket);
      reconnecting.disconnectedAt = null;
      _cancelExpiration(reconnecting);
      return JoinResult(session: reconnecting, reconnected: true);
    }
    if (requestedSessionToken != null) {
      throw const RuleError(
        'La sesion ya no es valida para esta partida. Vuelve a entrar sin token.',
      );
    }

    final PlayerSession? sessionByAlias = _sessionByAlias(alias);
    if (sessionByAlias != null) {
      throw RuleError('El alias $alias ya esta ocupado en esta partida.');
    }

    final Set<int> ocupados = _sessionsByToken.values
        .map((session) => session.playerId)
        .toSet();
    final int playerId = List<int>.generate(
      game.numeroJugadores,
      (int i) => i,
    ).firstWhere((int id) => !ocupados.contains(id), orElse: () => -1);

    if (playerId < 0) {
      throw const RuleError('La partida ya esta completa.');
    }

    game.players[playerId].name = alias;

    final PlayerSession session = PlayerSession(
      token: _generarTokenSesion(),
      playerId: playerId,
      playerName: alias,
      clientId: normalizedClientId,
    );
    _sessionsByToken[session.token] = session;
    _replaceSocket(session, socket);

    await _partidaStore.registrarEvento(
      gameId: id,
      playerId: playerId,
      tipo: TipoMensajeRemoto.join,
      payload: <String, dynamic>{'playerName': alias},
    );
    await _guardarSnapshot();

    return JoinResult(session: session, reconnected: false);
  }

  /// Busca una sesion por alias de jugador.
  PlayerSession? _sessionByAlias(String alias) {
    for (final PlayerSession session in _sessionsByToken.values) {
      if (session.playerName == alias) {
        return session;
      }
    }
    return null;
  }

  /// Aplica una accion enviada por un jugador remoto.
  Future<void> handleAction(
    PlayerSession session,
    String action,
    Map<String, dynamic> payload,
  ) async {
    if (session.playerId != game.indiceJugadorActual) {
      throw const RuleError('No es tu turno.');
    }

    bool resultado = false;
    switch (action) {
      case TipoAccionRemota.income:
        game.accionIngresos();
        resultado = true;
        break;
      case TipoAccionRemota.buyDeed:
        resultado = game.comprarParcela(payload['index'] as int? ?? -1);
        break;
      case TipoAccionRemota.build:
        resultado = _ejecutarConstruccionRemota(session, payload);
        break;
      default:
        throw RuleError('Accion no soportada: $action');
    }

    if (!resultado) {
      throw RuleError('La accion $action no pudo aplicarse.');
    }

    await _partidaStore.registrarEvento(
      gameId: id,
      playerId: session.playerId,
      tipo: action,
      payload: payload,
    );
    await _emitirResumenesPendientes();
    await _guardarSnapshot();
    broadcastSnapshot();
  }

  /// Devuelve la sesion asociada a un socket.
  PlayerSession? sessionForSocket(WebSocket socket) {
    return _sessionsBySocket[socket];
  }

  /// Marca un socket como desconectado e inicia temporizador de expiracion.
  void disconnect(WebSocket socket) {
    final PlayerSession? session = _sessionsBySocket.remove(socket);
    if (session == null) {
      return;
    }
    session.socket = null;
    session.disconnectedAt = DateTime.now();
    _scheduleExpiration(session);
    broadcastPresence(
      event: EventoPresenciaRemota.playerDisconnected,
      playerId: session.playerId,
      playerName: session.playerName,
    );
  }

  /// Cierra todos los sockets de la sala con un motivo.
  void closeSockets(String reason) {
    _suspended = true;
    _cancelAllExpirations();
    final List<WebSocket> sockets = _sessionsBySocket.keys.toList();
    _sessionsBySocket.clear();
    for (final PlayerSession session in _sessionsByToken.values) {
      session.socket = null;
    }
    for (final WebSocket socket in sockets) {
      socket.close(WebSocketStatus.normalClosure, reason);
    }
  }

  /// Expira una sesion desconectada y suspende la partida.
  bool expireDisconnectedSession(String sessionToken) {
    final PlayerSession? session = _sessionsByToken[sessionToken];
    if (session == null || session.connected || _suspended) {
      return false;
    }

    _suspended = true;
    _cancelAllExpirations();
    final String message =
        '${session.playerName} lleva mas de 3 minutos desconectado. '
        'La partida remota ha sido finalizada.';
    _broadcastError(message);
    closeSockets(message);
    _onSuspended?.call(this);
    return true;
  }

  /// Envia al jugador el mensaje joined con token y snapshot inicial.
  void sendJoined(PlayerSession session) {
    _send(
      session.socket,
      JoinedMessage(
        gameId: id,
        roomAlias: roomAlias,
        sessionToken: session.token,
        playerId: session.playerId,
        playerName: session.playerName,
        game: game.toJson(includePendingSummary: false),
      ).toJson(),
    );
  }

  /// Confirma una accion aceptada por requestId.
  void sendActionAccepted(WebSocket socket, String? requestId) {
    if (requestId == null || requestId.isEmpty) {
      return;
    }
    _send(socket, ActionAcceptedMessage(requestId: requestId).toJson());
  }

  /// Rechaza una accion por requestId, o envia error si no habia requestId.
  void sendActionRejected(WebSocket socket, String? requestId, String message) {
    if (requestId == null || requestId.isEmpty) {
      sendError(socket, message);
      return;
    }
    _send(
      socket,
      ActionRejectedMessage(requestId: requestId, message: message).toJson(),
    );
  }

  /// Envia el leaderboard actual a un socket.
  Future<void> sendLeaderboard(WebSocket socket) async {
    _send(socket, await _leaderboardMessage());
  }

  /// Envia un error remoto a un socket concreto.
  void sendError(WebSocket? socket, String message) {
    _send(socket, ErrorMessage(message: message).toJson());
  }

  /// Envia el snapshot actual a todos los sockets conectados.
  void broadcastSnapshot() {
    final Map<String, dynamic> snapshot = SnapshotMessage(
      gameId: id,
      game: game.toJson(includePendingSummary: false),
    ).toJson();
    for (final PlayerSession session in _sessionsBySocket.values) {
      _send(session.socket, snapshot);
    }
  }

  /// Envia un evento de presencia a todos los sockets conectados.
  void broadcastPresence({
    required String event,
    required int playerId,
    required String playerName,
  }) {
    final Map<String, dynamic> payload = PresenceMessage(
      gameId: id,
      event: event,
      playerId: playerId,
      playerName: playerName,
      expectedPlayerCount: game.numeroJugadores,
      connectedPlayerIds: connectedPlayerIds,
    ).toJson();

    for (final PlayerSession session in _sessionsBySocket.values) {
      _send(session.socket, payload);
    }
  }

  /// Envia el leaderboard actual a toda la sala.
  Future<void> broadcastLeaderboard() async {
    final Map<String, dynamic> message = await _leaderboardMessage();
    for (final PlayerSession session in _sessionsBySocket.values) {
      _send(session.socket, message);
    }
  }

  /// Ejecuta la accion remota de construccion sobre el motor.
  bool _ejecutarConstruccionRemota(
    PlayerSession session,
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
        ? game.monumentosDisponibles.indexWhere(
            (Edificio building) => building.id == templateId,
          )
        : game.players[session.playerId].availableBuildings.indexWhere(
            (Edificio building) => building.id == templateId,
          );
    if (buildingIdx < 0) {
      throw const RuleError('El edificio seleccionado ya no esta disponible.');
    }

    return game.construir(
      originCoord,
      template,
      rotationIndex,
      buildingIdx,
      isFromMonument,
    );
  }

  /// Emite resumenes pendientes generados por el motor de juego.
  Future<void> _emitirResumenesPendientes() async {
    while (true) {
      final Map<String, dynamic>? resumen = game.consumirResumenPendiente();
      if (resumen == null) {
        return;
      }

      await _registrarRankingFinalSiProcede(resumen);

      final Map<String, dynamic> mensaje = EraSummaryMessage(
        gameId: id,
        summary: resumen,
      ).toJson();
      for (final PlayerSession session in _sessionsBySocket.values) {
        _send(session.socket, mensaje);
      }

      game.confirmarResumenPendiente();
    }
  }

  /// Registra ranking final una unica vez si el resumen es final.
  Future<void> _registrarRankingFinalSiProcede(
    Map<String, dynamic> resumen,
  ) async {
    if (_rankingFinalPersistido || resumen['isFinal'] != true) {
      return;
    }

    for (final Jugador jugador in game.players) {
      await _rankingGlobal.registrarPuntuacionMaxima(
        alias: jugador.name,
        puntuacion: jugador.glory,
      );
    }

    _rankingFinalPersistido = true;
    await broadcastLeaderboard();
  }

  /// Construye el mensaje de leaderboard desde el repositorio.
  Future<Map<String, dynamic>> _leaderboardMessage() async {
    return LeaderboardMessage(
      entries: await _rankingGlobal.cargarTop10(),
    ).toJson();
  }

  /// Guarda el snapshot actual de la partida.
  Future<void> _guardarSnapshot() {
    return _partidaStore.guardarSnapshot(
      gameId: id,
      snapshot: game.toJson(includePendingSummary: false),
    );
  }

  /// Sustituye el socket activo de una sesion.
  void _replaceSocket(PlayerSession session, WebSocket socket) {
    final WebSocket? previousSocket = session.socket;
    if (previousSocket != null) {
      _sessionsBySocket.remove(previousSocket);
      previousSocket.close(WebSocketStatus.normalClosure, 'Reconexion');
    }
    session.socket = socket;
    session.disconnectedAt = null;
    _sessionsBySocket[socket] = session;
  }

  /// Programa la expiracion de una sesion desconectada.
  void _scheduleExpiration(PlayerSession session) {
    _cancelExpiration(session);
    _expirationTimersByToken[session.token] = Timer(
      _disconnectedGracePeriod,
      () {
        expireDisconnectedSession(session.token);
      },
    );
  }

  /// Cancela la expiracion pendiente de una sesion.
  void _cancelExpiration(PlayerSession session) {
    _expirationTimersByToken.remove(session.token)?.cancel();
  }

  /// Cancela todas las expiraciones pendientes.
  void _cancelAllExpirations() {
    for (final Timer timer in _expirationTimersByToken.values) {
      timer.cancel();
    }
    _expirationTimersByToken.clear();
  }

  /// Envia un error a todos los sockets conectados.
  void _broadcastError(String message) {
    final Map<String, dynamic> payload = ErrorMessage(
      message: message,
    ).toJson();
    for (final PlayerSession session in _sessionsBySocket.values) {
      _send(session.socket, payload);
    }
  }

  /// Codifica y envia un payload del protocolo remoto.
  void _send(WebSocket? socket, Map<String, dynamic> payload) {
    if (socket == null) {
      return;
    }
    socket.add(ProtocoloRemoto.codificarJson(payload));
  }

  /// Genera un token opaco de sesion para reconexion.
  String _generarTokenSesion() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
