// Estado de una plaza conectada a una sala remota. Mantiene token, alias,
// socket activo y datos necesarios para reconexion.

import 'dart:io';

/// Sesion de jugador dentro de una sala.
class PlayerSession {
  PlayerSession({
    required this.token,
    required this.playerId,
    required this.playerName,
    required this.clientId,
  });

  final String token;
  final int playerId;
  String playerName;
  String clientId;
  WebSocket? socket;
  DateTime? disconnectedAt;

  /// Indica si la sesion tiene un WebSocket activo.
  bool get connected => socket != null;
}
