// Servidor backend de Foundations of Rome. Expone endpoints HTTP, acepta
// conexiones WebSocket, gestiona salas remotas y delega reglas/persistencia en
// las capas correspondientes.

import 'dart:convert';
import 'dart:io';

import 'package:for_core/core.dart';
import 'package:for_core/protocol.dart';
import 'logging/server_logger.dart';
import 'persistence/partida_repository.dart';
import 'persistence/ranking_repository.dart';
import 'rooms/game_room.dart';
import 'rooms/game_room_manager.dart';
import 'rooms/player_session.dart';

/// Servidor HTTP/WebSocket principal del backend.
class FoundationsServer {
  FoundationsServer({
    required int defaultPlayerCount,
    required RankingRepository rankingGlobal,
    required PartidaRepository partidaStore,
    required String descripcionRanking,
    ServerLogger logger = const ServerLogger(),
    String accessToken = '',
    bool restoreRoomsOnStart = false,
    Duration disconnectedGracePeriod = const Duration(minutes: 3),
  }) : _defaultPlayerCount = defaultPlayerCount,
       _rankingGlobal = rankingGlobal,
       _partidaStore = partidaStore,
       _descripcionRanking = descripcionRanking,
       _logger = logger,
       _accessToken = accessToken,
       _restoreRoomsOnStart = restoreRoomsOnStart {
    _rooms = GameRoomManager(
      rankingGlobal: rankingGlobal,
      partidaStore: partidaStore,
      disconnectedGracePeriod: disconnectedGracePeriod,
      onRoomSuspended: _handleRoomSuspended,
    );
  }

  final int _defaultPlayerCount;
  final RankingRepository _rankingGlobal;
  final PartidaRepository _partidaStore;
  final String _descripcionRanking;
  final ServerLogger _logger;
  final String _accessToken;
  final bool _restoreRoomsOnStart;
  late final GameRoomManager _rooms;
  final Map<WebSocket, GameRoom> _roomBySocket = <WebSocket, GameRoom>{};

  HttpServer? _server;
  bool _cerrado = false;

  /// Puerto real al que se ha enlazado el servidor.
  int? get boundPort => _server?.port;

  /// Arranca el servidor y empieza a atender HTTP y WebSocket.
  Future<void> start({required String host, required int port}) async {
    if (_restoreRoomsOnStart) {
      final int restored = await _rooms.restoreRoomsFromSnapshots();
      _logger.info('Salas restauradas desde snapshots: $restored.');
    }

    _server = await HttpServer.bind(host, port);
    final int actualPort = _server!.port;
    _logger.info(
      'Servidor listo en http://$host:$actualPort y ws://$host:$actualPort.',
    );
    _logger.info('Ranking global: $_descripcionRanking');

    await for (final HttpRequest request in _server!) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        await _handleWebSocket(request);
        continue;
      }
      await _handleHttp(request);
    }
  }

  /// Atiende endpoints HTTP de salud, ranking, salas y snapshots.
  Future<void> _handleHttp(HttpRequest request) async {
    try {
      final List<String> segments = request.uri.pathSegments;
      if (request.method == 'GET' && segments.isEmpty) {
        _sendJson(request, <String, dynamic>{
          'name': 'Foundations of Rome server',
          'status': 'ok',
        });
        return;
      }

      if (request.method == 'GET' &&
          _matches(segments, const <String>['health'])) {
        _sendJson(
          request,
          HealthResponse(
            status: 'ok',
            rooms: _rooms.rooms.length,
            ranking: _descripcionRanking,
          ).toJson(),
        );
        return;
      }

      if (request.method == 'GET' &&
          _matches(segments, const <String>['leaderboard'])) {
        _sendJson(request, <String, dynamic>{
          'entries': (await _rankingGlobal.cargarTop10())
              .map((EntradaClasificacion entrada) => entrada.toJson())
              .toList(growable: false),
        });
        return;
      }

      if (request.method == 'GET' &&
          _matches(segments, const <String>['games'])) {
        _sendJson(request, <String, dynamic>{
          'games': _rooms.rooms
              .map((GameRoom room) => room.toSummary())
              .toList(growable: false),
        });
        return;
      }

      if (request.method == 'POST' &&
          _matches(segments, const <String>['games'])) {
        if (!_httpAutorizado(request)) {
          _sendJson(request, <String, dynamic>{
            'error': 'Token de acceso invalido.',
          }, statusCode: HttpStatus.unauthorized);
          return;
        }
        final Map<String, dynamic> body;
        final CreateGameRequest createRequest;
        try {
          body = await _readJsonBody(request);
          createRequest = CreateGameRequest.fromJson(body);
        } on FormatException catch (error) {
          _sendJson(request, <String, dynamic>{
            'error': error.message,
          }, statusCode: HttpStatus.badRequest);
          return;
        }
        final int players = body.containsKey('players')
            ? createRequest.players
            : _defaultPlayerCount;
        final GameRoom room;
        try {
          room = await _rooms.createRoom(
            playerCount: players,
            roomAlias: createRequest.roomAlias,
          );
        } on FormatException catch (error) {
          _sendJson(request, <String, dynamic>{
            'error': error.message,
          }, statusCode: HttpStatus.badRequest);
          return;
        }
        _sendJson(
          request,
          CreateGameResponse(
            game: room.toSummary(),
            wsPath: room.roomAlias == null
                ? '/games/${room.id}/ws'
                : '/rooms/${room.roomAlias}/ws',
          ).toJson(),
          statusCode: HttpStatus.created,
        );
        return;
      }

      if (request.method == 'DELETE' &&
          segments.length == 2 &&
          segments.first == 'games') {
        if (!_httpAutorizado(request)) {
          _sendJson(request, <String, dynamic>{
            'error': 'Token de acceso invalido.',
          }, statusCode: HttpStatus.unauthorized);
          return;
        }

        final GameRoom? room =
            _rooms.getRoom(segments[1]) ?? _rooms.getRoomByAlias(segments[1]);
        if (room == null) {
          _sendJson(request, <String, dynamic>{
            'error': 'Partida no encontrada.',
          }, statusCode: HttpStatus.notFound);
          return;
        }

        _closeRoom(room, reason: 'Sala cerrada por HTTP.');
        _sendJson(request, <String, dynamic>{
          'closed': true,
          'gameId': room.id,
        });
        return;
      }

      if (request.method == 'GET' &&
          segments.length == 2 &&
          segments.first == 'games') {
        final GameRoom? room =
            _rooms.getRoom(segments[1]) ?? _rooms.getRoomByAlias(segments[1]);
        if (room == null) {
          _sendJson(request, <String, dynamic>{
            'error': 'Partida no encontrada.',
          }, statusCode: HttpStatus.notFound);
          return;
        }
        _sendJson(request, <String, dynamic>{
          'game': room.toSummary(),
          'snapshot': room.game.toJson(includePendingSummary: false),
        });
        return;
      }

      _sendJson(request, <String, dynamic>{
        'error': 'Ruta no encontrada.',
      }, statusCode: HttpStatus.notFound);
    } catch (error) {
      _logger.error('Error HTTP inesperado', error);
      _sendJson(request, <String, dynamic>{
        'error': error.toString(),
      }, statusCode: HttpStatus.internalServerError);
    }
  }

  /// Acepta una conexion WebSocket y registra sus callbacks.
  Future<void> _handleWebSocket(HttpRequest request) async {
    final String? gameIdFromPath = _gameIdFromWebSocketPath(request.uri);
    final String? roomAliasFromPath = _roomAliasFromWebSocketPath(request.uri);
    final String? accessTokenFromRequest =
        _accessTokenFromAuthorizationHeader(request) ??
        _accessTokenFromUri(request.uri);
    final WebSocket socket = await WebSocketTransformer.upgrade(request);

    socket.listen(
      (dynamic data) {
        _handleWebSocketMessage(
          socket,
          data,
          gameIdFromPath: gameIdFromPath,
          roomAliasFromPath: roomAliasFromPath,
          accessTokenFromQuery: accessTokenFromRequest,
        );
      },
      onDone: () => _disconnect(socket),
      onError: (_) => _disconnect(socket),
      cancelOnError: true,
    );
  }

  /// Decodifica y enruta mensajes WebSocket por tipo.
  Future<void> _handleWebSocketMessage(
    WebSocket socket,
    dynamic rawData, {
    required String? gameIdFromPath,
    required String? roomAliasFromPath,
    required String? accessTokenFromQuery,
  }) async {
    try {
      final Map<String, dynamic> message = ProtocoloRemoto.decodificarJson(
        rawData as String,
      );
      final String type = ProtocoloRemoto.tipoDe(message);

      switch (type) {
        case TipoMensajeRemoto.join:
          await _handleJoin(
            socket,
            message,
            gameIdFromPath: gameIdFromPath,
            roomAliasFromPath: roomAliasFromPath,
            accessTokenFromQuery: accessTokenFromQuery,
          );
          return;
        case TipoMensajeRemoto.getLeaderboard:
          await _sendLeaderboard(socket);
          return;
        case TipoMensajeRemoto.action:
          await _handleAction(socket, message);
          return;
        default:
          _sendError(socket, 'Tipo de mensaje no soportado: $type');
      }
    } catch (error) {
      _logger.warning('Mensaje WebSocket invalido: $error');
      _sendError(socket, 'Mensaje invalido: $error');
    }
  }

  /// Procesa el mensaje join y une/reconecta al jugador a una sala.
  Future<void> _handleJoin(
    WebSocket socket,
    Map<String, dynamic> message, {
    required String? gameIdFromPath,
    required String? roomAliasFromPath,
    required String? accessTokenFromQuery,
  }) async {
    final JoinRequest request = JoinRequest.fromJson(message);
    if (!_tokenAutorizado(request.accessToken ?? accessTokenFromQuery)) {
      _sendError(socket, 'Token de acceso invalido.');
      await socket.close(WebSocketStatus.policyViolation, 'No autorizado');
      return;
    }
    final String? requestedGameId = request.gameId?.trim().isNotEmpty == true
        ? request.gameId!.trim()
        : gameIdFromPath;
    final String? requestedRoomAlias =
        request.roomAlias?.trim().isNotEmpty == true
        ? request.roomAlias!.trim()
        : roomAliasFromPath;

    _RoomForJoinResult? roomResult;
    try {
      roomResult = await _roomForJoin(
        gameId: requestedGameId,
        roomAlias: requestedRoomAlias,
        createRoom: request.createRoom,
        players: request.players ?? _defaultPlayerCount,
        hasSessionToken: request.sessionToken?.trim().isNotEmpty == true,
      );
      final GameRoom room = roomResult.room;
      final JoinResult result = await room.join(
        socket: socket,
        playerName: request.playerName,
        clientId: request.clientId ?? '',
        sessionToken: request.sessionToken,
      );
      _roomBySocket[socket] = room;
      room.sendJoined(result.session);
      await room.sendLeaderboard(socket);
      room.broadcastSnapshot();
      room.broadcastPresence(
        event: result.reconnected ? 'playerReconnected' : 'playerJoined',
        playerId: result.session.playerId,
        playerName: result.session.playerName,
      );
    } on RuleError catch (error) {
      _logger.warning(error.message);
      final _RoomForJoinResult? failedRoomResult = roomResult;
      if (failedRoomResult != null &&
          failedRoomResult.created &&
          failedRoomResult.room.connectedCount == 0 &&
          failedRoomResult.room.sessionCount == 0) {
        _rooms.removeRoom(failedRoomResult.room.id);
      }
      _sendError(socket, error.message);
      await socket.close(WebSocketStatus.policyViolation, error.message);
    }
  }

  /// Procesa una accion remota y responde con accepted/rejected.
  Future<void> _handleAction(
    WebSocket socket,
    Map<String, dynamic> message,
  ) async {
    final GameRoom? room = _roomBySocket[socket];
    final PlayerSession? session = room?.sessionForSocket(socket);
    final ActionRequest request = ActionRequest.fromJson(message);
    final String requestId = request.requestId;
    if (room == null || session == null) {
      _sendActionRejected(
        socket,
        requestId,
        'Debes unirte antes de enviar acciones.',
      );
      return;
    }

    try {
      await room.handleAction(session, request.action, request.payload);
      room.sendActionAccepted(socket, requestId);
    } on RuleError catch (error) {
      room.sendActionRejected(socket, requestId, error.message);
    }
  }

  /// Envia leaderboard por WebSocket, con o sin sala asociada.
  Future<void> _sendLeaderboard(WebSocket socket) async {
    final GameRoom? room = _roomBySocket[socket];
    if (room != null) {
      await room.sendLeaderboard(socket);
      return;
    }

    socket.add(
      ProtocoloRemoto.codificarJson(
        LeaderboardMessage(
          entries: await _rankingGlobal.cargarTop10(),
        ).toJson(),
      ),
    );
  }

  /// Envia rechazo de accion ligado a requestId.
  void _sendActionRejected(
    WebSocket socket,
    String? requestId,
    String message,
  ) {
    if (requestId == null || requestId.isEmpty) {
      _sendError(socket, message);
      return;
    }

    socket.add(
      ProtocoloRemoto.codificarJson(
        ActionRejectedMessage(requestId: requestId, message: message).toJson(),
      ),
    );
  }

  /// Envia error generico por WebSocket.
  void _sendError(WebSocket socket, String message) {
    socket.add(
      ProtocoloRemoto.codificarJson(ErrorMessage(message: message).toJson()),
    );
  }

  /// Desconecta un socket de su sala.
  void _disconnect(WebSocket socket) {
    final GameRoom? room = _roomBySocket.remove(socket);
    if (room == null) {
      return;
    }
    room.disconnect(socket);
    if (room.suspended) {
      _rooms.removeRoom(room.id);
      _logger.info('Sala ${room.id} eliminada al quedar suspendida.');
    }
  }

  /// Cierra y elimina una sala completa.
  void _closeRoom(GameRoom room, {required String reason}) {
    for (final WebSocket socket in room.connectedSockets.toList()) {
      _roomBySocket.remove(socket);
    }
    room.closeSockets(reason);
    _rooms.removeRoom(room.id);
    _logger.info('Sala ${room.id} cerrada.');
  }

  /// Elimina referencias a una sala suspendida por desconexion prolongada.
  void _handleRoomSuspended(GameRoom room) {
    for (final WebSocket socket in room.connectedSockets.toList()) {
      _roomBySocket.remove(socket);
    }
    _rooms.removeRoom(room.id);
    _logger.warning('Sala ${room.id} suspendida por desconexion prolongada.');
  }

  /// Resuelve que sala usar al recibir un join.
  Future<_RoomForJoinResult> _roomForJoin({
    required String? gameId,
    required String? roomAlias,
    required bool createRoom,
    required int players,
    required bool hasSessionToken,
  }) async {
    if (roomAlias != null) {
      final GameRoom? room = _rooms.getRoomByAlias(roomAlias);
      if (room != null) {
        if (createRoom && !hasSessionToken) {
          throw RuleError(
            'La sala ${GameRoomManager.normalizeRoomAlias(roomAlias)} ya existe.',
          );
        }
        return _RoomForJoinResult(room: room, created: false);
      }
      if (createRoom) {
        try {
          final GameRoom room = await _rooms.createRoom(
            playerCount: players,
            roomAlias: roomAlias,
          );
          return _RoomForJoinResult(room: room, created: true);
        } on FormatException catch (error) {
          throw RuleError(error.message);
        }
      }
      throw RuleError('Sala no encontrada: $roomAlias');
    }

    if (gameId != null) {
      final GameRoom? room = _rooms.getRoom(gameId);
      if (room != null) {
        return _RoomForJoinResult(room: room, created: false);
      }
      if (gameId == 'game_0001' && _rooms.rooms.isEmpty) {
        return _RoomForJoinResult(
          room: await _rooms.createRoom(playerCount: _defaultPlayerCount),
          created: true,
        );
      }
      throw RuleError('Partida no encontrada: $gameId');
    }

    if (createRoom) {
      try {
        final GameRoom room = await _rooms.createRoom(playerCount: players);
        return _RoomForJoinResult(room: room, created: true);
      } on FormatException catch (error) {
        throw RuleError(error.message);
      }
    }

    return _RoomForJoinResult(
      room: await _rooms.getOrCreateDefaultRoom(
        playerCount: _defaultPlayerCount,
      ),
      created: false,
    );
  }

  /// Extrae gameId desde rutas WebSocket `/games/<id>/ws`.
  String? _gameIdFromWebSocketPath(Uri uri) {
    final List<String> segments = uri.pathSegments;
    if (segments.length == 3 && segments[0] == 'games' && segments[2] == 'ws') {
      return segments[1];
    }
    return null;
  }

  /// Extrae alias desde rutas WebSocket `/rooms/<alias>/ws`.
  String? _roomAliasFromWebSocketPath(Uri uri) {
    final List<String> segments = uri.pathSegments;
    if (segments.length == 3 && segments[0] == 'rooms' && segments[2] == 'ws') {
      return segments[1];
    }
    return null;
  }

  /// Comprueba token en cabecera o query para endpoints HTTP protegidos.
  bool _httpAutorizado(HttpRequest request) {
    return _tokenAutorizado(
      _accessTokenFromAuthorizationHeader(request) ??
          request.headers.value('x-for-access-token') ??
          _accessTokenFromUri(request.uri),
    );
  }

  /// Valida token opcional configurado en el servidor.
  bool _tokenAutorizado(String? token) {
    if (_accessToken.isEmpty) {
      return true;
    }
    if (token == null) {
      return false;
    }
    return _constantTimeEquals(token, _accessToken);
  }

  /// Lee token de acceso desde query string.
  String? _accessTokenFromUri(Uri uri) {
    return uri.queryParameters['token'] ?? uri.queryParameters['accessToken'];
  }

  /// Lee token Bearer desde cabecera Authorization.
  String? _accessTokenFromAuthorizationHeader(HttpRequest request) {
    final String? rawHeader = request.headers.value(
      HttpHeaders.authorizationHeader,
    );
    if (rawHeader == null || rawHeader.trim().isEmpty) {
      return null;
    }
    final String header = rawHeader.trim();
    const String bearerPrefix = 'Bearer ';
    if (header.length > bearerPrefix.length &&
        header.substring(0, bearerPrefix.length).toLowerCase() ==
            bearerPrefix.toLowerCase()) {
      return header.substring(bearerPrefix.length).trim();
    }
    return null;
  }

  /// Compara tokens sin cortar al primer caracter distinto.
  bool _constantTimeEquals(String a, String b) {
    final List<int> aUnits = a.codeUnits;
    final List<int> bUnits = b.codeUnits;
    if (aUnits.length != bUnits.length) {
      return false;
    }

    int diff = 0;
    for (int index = 0; index < aUnits.length; index++) {
      diff |= aUnits[index] ^ bUnits[index];
    }
    return diff == 0;
  }

  /// Comprueba si los segmentos de una ruta coinciden exactamente.
  bool _matches(List<String> actual, List<String> expected) {
    if (actual.length != expected.length) {
      return false;
    }
    for (int index = 0; index < actual.length; index++) {
      if (actual[index] != expected[index]) {
        return false;
      }
    }
    return true;
  }

  /// Lee y decodifica cuerpo JSON de una peticion HTTP.
  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final String rawBody = await utf8.decoder.bind(request).join();
    if (rawBody.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final dynamic decoded = jsonDecode(rawBody);
    if (decoded is! Map) {
      throw const FormatException('El cuerpo debe ser un objeto JSON.');
    }
    return decoded.cast<String, dynamic>();
  }

  /// Responde una peticion HTTP con JSON.
  void _sendJson(
    HttpRequest request,
    Map<String, dynamic> payload, {
    int statusCode = HttpStatus.ok,
  }) {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload))
      ..close();
  }

  /// Cierra servidor, salas, sockets y repositorios.
  Future<void> close() async {
    if (_cerrado) {
      return;
    }
    _cerrado = true;
    for (final GameRoom room in _rooms.rooms.toList(growable: false)) {
      room.closeSockets('Servidor cerrado.');
      _rooms.removeRoom(room.id);
    }
    await _server?.close(force: true);
    await _rankingGlobal.close();
    await _partidaStore.close();
    _logger.info('Servidor cerrado.');
  }
}

/// Resultado interno de resolver una sala para un join.
class _RoomForJoinResult {
  const _RoomForJoinResult({required this.room, required this.created});

  final GameRoom room;
  final bool created;
}
