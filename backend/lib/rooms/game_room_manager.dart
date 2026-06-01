// Gestor de salas remotas. Crea, busca, restaura y elimina GameRoom, ademas de
// reservar alias legibles de sala.

import '../persistence/partida_repository.dart';
import '../persistence/ranking_repository.dart';
import 'game_room.dart';

/// Administra el conjunto de salas activas del servidor.
class GameRoomManager {
  GameRoomManager({
    required RankingRepository rankingGlobal,
    required PartidaRepository partidaStore,
    Duration disconnectedGracePeriod = const Duration(minutes: 3),
    void Function(GameRoom room)? onRoomSuspended,
  }) : _rankingGlobal = rankingGlobal,
       _partidaStore = partidaStore,
       _disconnectedGracePeriod = disconnectedGracePeriod,
       _onRoomSuspended = onRoomSuspended;

  final RankingRepository _rankingGlobal;
  final PartidaRepository _partidaStore;
  final Duration _disconnectedGracePeriod;
  final void Function(GameRoom room)? _onRoomSuspended;
  final Map<String, GameRoom> _rooms = <String, GameRoom>{};
  final Map<String, String> _roomIdByAlias = <String, String>{};
  int _nextRoomNumber = 1;

  /// Salas actualmente registradas.
  Iterable<GameRoom> get rooms => _rooms.values;

  /// Restaura salas desde snapshots persistidos al arrancar.
  Future<int> restoreRoomsFromSnapshots() async {
    final List<PartidaSnapshot> snapshots = await _partidaStore
        .cargarSnapshots();
    int restored = 0;
    for (final PartidaSnapshot partidaSnapshot in snapshots) {
      if (_rooms.containsKey(partidaSnapshot.gameId)) {
        continue;
      }
      final GameRoom room = GameRoom.fromSnapshot(
        id: partidaSnapshot.gameId,
        snapshot: partidaSnapshot.snapshot,
        rankingGlobal: _rankingGlobal,
        partidaStore: _partidaStore,
        disconnectedGracePeriod: _disconnectedGracePeriod,
        onSuspended: _onRoomSuspended,
      );
      _rooms[room.id] = room;
      final int nextCandidate = _roomNumberFromId(room.id) + 1;
      if (nextCandidate > _nextRoomNumber) {
        _nextRoomNumber = nextCandidate;
      }
      restored++;
    }
    return restored;
  }

  /// Crea una sala nueva con numero de jugadores y alias opcional.
  Future<GameRoom> createRoom({
    required int playerCount,
    String? roomAlias,
  }) async {
    if (playerCount < 2 || playerCount > 5) {
      throw const FormatException(
        'El numero de jugadores debe estar entre 2 y 5.',
      );
    }
    final String? normalizedAlias = normalizeRoomAlias(roomAlias);
    if (normalizedAlias != null &&
        _roomIdByAlias.containsKey(normalizedAlias)) {
      throw FormatException('La sala $normalizedAlias ya existe.');
    }

    final String id = 'game_${_nextRoomNumber.toString().padLeft(4, '0')}';
    _nextRoomNumber++;

    final GameRoom room = GameRoom(
      id: id,
      roomAlias: normalizedAlias,
      playerCount: playerCount,
      rankingGlobal: _rankingGlobal,
      partidaStore: _partidaStore,
      disconnectedGracePeriod: _disconnectedGracePeriod,
      onSuspended: _onRoomSuspended,
    );
    _rooms[id] = room;
    if (normalizedAlias != null) {
      _roomIdByAlias[normalizedAlias] = id;
    }
    await room.registrarCreacion();
    return room;
  }

  /// Busca una sala por id interno.
  GameRoom? getRoom(String id) {
    return _rooms[id];
  }

  /// Busca una sala por alias legible.
  GameRoom? getRoomByAlias(String alias) {
    final String? normalizedAlias = normalizeRoomAlias(alias);
    if (normalizedAlias == null) {
      return null;
    }
    final String? roomId = _roomIdByAlias[normalizedAlias];
    return roomId == null ? null : _rooms[roomId];
  }

  /// Elimina una sala y libera su alias.
  void removeRoom(String id) {
    final GameRoom? room = _rooms.remove(id);
    final String? roomAlias = room?.roomAlias;
    if (roomAlias != null) {
      _roomIdByAlias.remove(roomAlias);
    }
    if (_rooms.isEmpty) {
      _nextRoomNumber = 1;
    }
  }

  /// Devuelve la primera sala existente o crea una sala por defecto.
  Future<GameRoom> getOrCreateDefaultRoom({required int playerCount}) async {
    if (_rooms.isNotEmpty) {
      return _rooms.values.first;
    }
    return createRoom(playerCount: playerCount);
  }

  /// Normaliza y valida alias de sala.
  static String? normalizeRoomAlias(String? rawAlias) {
    final String alias = rawAlias?.trim().toUpperCase() ?? '';
    if (alias.isEmpty) {
      return null;
    }
    if (alias.length < 3 || alias.length > 20) {
      throw const FormatException(
        'El alias de sala debe tener entre 3 y 20 caracteres.',
      );
    }
    if (!RegExp(r'^[A-Z0-9_-]+$').hasMatch(alias)) {
      throw const FormatException(
        'El alias de sala solo puede contener letras, numeros, guion y guion bajo.',
      );
    }
    return alias;
  }

  /// Extrae el numero incremental desde ids tipo `game_0001`.
  int _roomNumberFromId(String gameId) {
    final RegExpMatch? match = RegExp(r'^game_(\d+)$').firstMatch(gameId);
    if (match == null) {
      return 0;
    }
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }
}
