// Contratos JSON compartidos por el cliente Flutter y el servidor. Este archivo
// evita que ambos lados dependan de strings sueltos para hablar por WebSocket y
// HTTP.

import 'dart:convert';

import '../core/entrada_leaderboard.dart';

/// Utilidades basicas del protocolo remoto.
abstract final class ProtocoloRemoto {
  static const int versionActual = 1;

  /// Decodifica un mensaje JSON recibido por WebSocket o HTTP.
  static Map<String, dynamic> decodificarJson(String rawMessage) {
    return (jsonDecode(rawMessage) as Map).cast<String, dynamic>();
  }

  /// Codifica un mapa como JSON para enviarlo por red.
  static String codificarJson(Map<String, dynamic> message) {
    return jsonEncode(message);
  }

  /// Extrae el tipo de mensaje de un mapa ya decodificado.
  static String tipoDe(Map<String, dynamic> message) {
    return (message[CampoMensaje.type] ?? '').toString();
  }
}

/// Nombres de campos usados en los mensajes del protocolo.
abstract final class CampoMensaje {
  static const String version = 'version';
  static const String type = 'type';
  static const String requestId = 'requestId';
  static const String gameId = 'gameId';
  static const String roomAlias = 'roomAlias';
  static const String sessionToken = 'sessionToken';
  static const String clientId = 'clientId';
  static const String accessToken = 'accessToken';
  static const String playerId = 'playerId';
  static const String playerName = 'playerName';
  static const String game = 'game';
  static const String action = 'action';
  static const String payload = 'payload';
  static const String message = 'message';
  static const String entries = 'entries';
  static const String summary = 'summary';
  static const String event = 'event';
  static const String expectedPlayerCount = 'expectedPlayerCount';
  static const String connectedPlayerIds = 'connectedPlayerIds';
}

/// Tipos de mensaje que viajan por WebSocket.
abstract final class TipoMensajeRemoto {
  static const String join = 'join';
  static const String joined = 'joined';
  static const String getLeaderboard = 'getLeaderboard';
  static const String leaderboard = 'leaderboard';
  static const String action = 'action';
  static const String actionAccepted = 'actionAccepted';
  static const String actionRejected = 'actionRejected';
  static const String snapshot = 'snapshot';
  static const String eraSummary = 'eraSummary';
  static const String presence = 'presence';
  static const String error = 'error';
}

/// Tipos de accion de juego enviadas por el cliente.
abstract final class TipoAccionRemota {
  static const String income = 'income';
  static const String buyDeed = 'buyDeed';
  static const String build = 'build';
}

/// Eventos de presencia de jugadores en una sala remota.
abstract final class EventoPresenciaRemota {
  static const String playerJoined = 'playerJoined';
  static const String playerReconnected = 'playerReconnected';
  static const String playerDisconnected = 'playerDisconnected';
}

/// Tipos de evento persistidos para una partida.
abstract final class TipoEventoPartida {
  static const String gameCreated = 'gameCreated';
}

/// Solicitud para crear o unirse a una sala remota.
class JoinRequest {
  const JoinRequest({
    required this.playerName,
    this.gameId,
    this.roomAlias,
    this.createRoom = false,
    this.players,
    this.sessionToken,
    this.clientId,
    this.accessToken,
  });

  final String playerName;
  final String? gameId;
  final String? roomAlias;
  final bool createRoom;
  final int? players;
  final String? sessionToken;
  final String? clientId;
  final String? accessToken;

  /// Reconstruye una solicitud de union desde JSON.
  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      playerName: (json[CampoMensaje.playerName] ?? '').toString(),
      gameId: json[CampoMensaje.gameId]?.toString(),
      roomAlias: json[CampoMensaje.roomAlias]?.toString(),
      createRoom: json['createRoom'] as bool? ?? false,
      players: json['players'] as int?,
      sessionToken: json[CampoMensaje.sessionToken] as String?,
      clientId: json[CampoMensaje.clientId] as String?,
      accessToken: json[CampoMensaje.accessToken] as String?,
    );
  }

  /// Serializa la solicitud para enviarla al servidor.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      CampoMensaje.version: ProtocoloRemoto.versionActual,
      CampoMensaje.type: TipoMensajeRemoto.join,
      if (gameId != null) CampoMensaje.gameId: gameId,
      if (roomAlias != null) CampoMensaje.roomAlias: roomAlias,
      if (createRoom) 'createRoom': true,
      if (players != null) 'players': players,
      if (sessionToken != null) CampoMensaje.sessionToken: sessionToken,
      if (clientId != null) CampoMensaje.clientId: clientId,
      if (accessToken != null) CampoMensaje.accessToken: accessToken,
      CampoMensaje.playerName: playerName,
    };
  }
}

/// Solicitud para obtener el leaderboard global.
class GetLeaderboardRequest {
  const GetLeaderboardRequest();

  /// Serializa la solicitud de leaderboard.
  Map<String, dynamic> toJson() {
    return const <String, dynamic>{
      CampoMensaje.version: ProtocoloRemoto.versionActual,
      CampoMensaje.type: TipoMensajeRemoto.getLeaderboard,
    };
  }
}

/// Solicitud de accion de partida con requestId para esperar respuesta.
class ActionRequest {
  const ActionRequest({
    required this.requestId,
    required this.action,
    this.payload = const <String, dynamic>{},
  });

  final String requestId;
  final String action;
  final Map<String, dynamic> payload;

  /// Reconstruye una accion remota desde JSON.
  factory ActionRequest.fromJson(Map<String, dynamic> json) {
    return ActionRequest(
      requestId: (json[CampoMensaje.requestId] ?? '').toString(),
      action: (json[CampoMensaje.action] ?? '').toString(),
      payload: ((json[CampoMensaje.payload] as Map?) ?? <String, dynamic>{})
          .cast<String, dynamic>(),
    );
  }

  /// Serializa la accion para enviarla por WebSocket.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      CampoMensaje.version: ProtocoloRemoto.versionActual,
      CampoMensaje.requestId: requestId,
      CampoMensaje.type: TipoMensajeRemoto.action,
      CampoMensaje.action: action,
      CampoMensaje.payload: payload,
    };
  }
}

/// Mensaje de union aceptada por el servidor.
class JoinedMessage {
  const JoinedMessage({
    required this.gameId,
    this.roomAlias,
    required this.sessionToken,
    required this.playerId,
    required this.playerName,
    required this.game,
  });

  final String gameId;
  final String? roomAlias;
  final String sessionToken;
  final int playerId;
  final String playerName;
  final Map<String, dynamic> game;

  /// Serializa el mensaje accepted/joined para el cliente.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      CampoMensaje.version: ProtocoloRemoto.versionActual,
      CampoMensaje.type: TipoMensajeRemoto.joined,
      CampoMensaje.gameId: gameId,
      if (roomAlias != null) CampoMensaje.roomAlias: roomAlias,
      CampoMensaje.sessionToken: sessionToken,
      CampoMensaje.playerId: playerId,
      CampoMensaje.playerName: playerName,
      CampoMensaje.game: game,
    };
  }
}

/// Confirmacion positiva de una accion remota.
class ActionAcceptedMessage {
  const ActionAcceptedMessage({required this.requestId});

  final String requestId;

  /// Serializa la confirmacion de accion aceptada.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      CampoMensaje.version: ProtocoloRemoto.versionActual,
      CampoMensaje.type: TipoMensajeRemoto.actionAccepted,
      CampoMensaje.requestId: requestId,
    };
  }
}

/// Confirmacion negativa de una accion remota.
class ActionRejectedMessage {
  const ActionRejectedMessage({required this.requestId, required this.message});

  final String requestId;
  final String message;

  /// Serializa el rechazo de accion con su mensaje.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      CampoMensaje.version: ProtocoloRemoto.versionActual,
      CampoMensaje.type: TipoMensajeRemoto.actionRejected,
      CampoMensaje.requestId: requestId,
      CampoMensaje.message: message,
    };
  }
}

/// Snapshot completo de partida enviado por el servidor.
class SnapshotMessage {
  const SnapshotMessage({required this.gameId, required this.game});

  final String gameId;
  final Map<String, dynamic> game;

  /// Serializa el snapshot de partida.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      CampoMensaje.version: ProtocoloRemoto.versionActual,
      CampoMensaje.type: TipoMensajeRemoto.snapshot,
      CampoMensaje.gameId: gameId,
      CampoMensaje.game: game,
    };
  }
}

/// Resumen de era o final enviado por el servidor.
class EraSummaryMessage {
  const EraSummaryMessage({required this.gameId, required this.summary});

  final String gameId;
  final Map<String, dynamic> summary;

  /// Serializa el resumen pendiente.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      CampoMensaje.version: ProtocoloRemoto.versionActual,
      CampoMensaje.type: TipoMensajeRemoto.eraSummary,
      CampoMensaje.gameId: gameId,
      CampoMensaje.summary: summary,
    };
  }
}

/// Mensaje de cambios de presencia dentro de una sala.
class PresenceMessage {
  const PresenceMessage({
    required this.gameId,
    required this.event,
    required this.playerId,
    required this.playerName,
    required this.expectedPlayerCount,
    required this.connectedPlayerIds,
  });

  final String gameId;
  final String event;
  final int playerId;
  final String playerName;
  final int expectedPlayerCount;
  final List<int> connectedPlayerIds;

  /// Serializa el estado de presencia.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      CampoMensaje.version: ProtocoloRemoto.versionActual,
      CampoMensaje.type: TipoMensajeRemoto.presence,
      CampoMensaje.gameId: gameId,
      CampoMensaje.event: event,
      CampoMensaje.playerId: playerId,
      CampoMensaje.playerName: playerName,
      CampoMensaje.expectedPlayerCount: expectedPlayerCount,
      CampoMensaje.connectedPlayerIds: connectedPlayerIds,
    };
  }
}

/// Respuesta con entradas del leaderboard global.
class LeaderboardMessage {
  const LeaderboardMessage({required this.entries});

  final List<EntradaClasificacion> entries;

  /// Reconstruye el leaderboard desde JSON.
  factory LeaderboardMessage.fromJson(Map<String, dynamic> json) {
    final List<dynamic> entriesJson =
        json[CampoMensaje.entries] as List<dynamic>? ?? const <dynamic>[];
    return LeaderboardMessage(
      entries: entriesJson
          .whereType<Map>()
          .map(
            (Map entry) =>
                EntradaClasificacion.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }

  /// Serializa el leaderboard para enviarlo al cliente.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      CampoMensaje.version: ProtocoloRemoto.versionActual,
      CampoMensaje.type: TipoMensajeRemoto.leaderboard,
      CampoMensaje.entries: entries
          .map((EntradaClasificacion entrada) => entrada.toJson())
          .toList(growable: false),
    };
  }
}

/// Mensaje generico de error remoto.
class ErrorMessage {
  const ErrorMessage({required this.message});

  final String message;

  /// Serializa el error remoto.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      CampoMensaje.version: ProtocoloRemoto.versionActual,
      CampoMensaje.type: TipoMensajeRemoto.error,
      CampoMensaje.message: message,
    };
  }
}

/// Resumen breve de una partida para endpoints HTTP.
class GameSummaryMessage {
  const GameSummaryMessage({
    required this.gameId,
    this.roomAlias,
    required this.players,
    required this.connectedPlayers,
    required this.reservedPlayers,
    required this.currentPlayerId,
    required this.finished,
  });

  final String gameId;
  final String? roomAlias;
  final int players;
  final int connectedPlayers;
  final int reservedPlayers;
  final int currentPlayerId;
  final bool finished;

  /// Serializa el resumen de partida.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      CampoMensaje.gameId: gameId,
      if (roomAlias != null) CampoMensaje.roomAlias: roomAlias,
      'players': players,
      'connectedPlayers': connectedPlayers,
      'reservedPlayers': reservedPlayers,
      'currentPlayerId': currentPlayerId,
      'finished': finished,
    };
  }
}

/// Respuesta del endpoint de salud del servidor.
class HealthResponse {
  const HealthResponse({
    required this.status,
    required this.rooms,
    required this.ranking,
  });

  final String status;
  final int rooms;
  final String ranking;

  /// Serializa el estado de salud.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status,
      'rooms': rooms,
      'ranking': ranking,
    };
  }
}

/// Solicitud HTTP para crear una partida.
class CreateGameRequest {
  const CreateGameRequest({required this.players, this.roomAlias});

  final int players;
  final String? roomAlias;

  /// Reconstruye la solicitud desde JSON.
  factory CreateGameRequest.fromJson(Map<String, dynamic> json) {
    return CreateGameRequest(
      players: _intFromJson(json['players']),
      roomAlias: json[CampoMensaje.roomAlias]?.toString(),
    );
  }

  /// Serializa la solicitud de creacion.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'players': players,
      if (roomAlias != null) CampoMensaje.roomAlias: roomAlias,
    };
  }
}

/// Convierte valores JSON flexibles a entero.
int _intFromJson(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is int) {
    return value;
  }
  if (value is num && value == value.roundToDouble()) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

/// Respuesta HTTP tras crear una partida.
class CreateGameResponse {
  const CreateGameResponse({required this.game, required this.wsPath});

  final Map<String, dynamic> game;
  final String wsPath;

  /// Serializa la respuesta de creacion de partida.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'game': game, 'wsPath': wsPath};
  }
}
