// Contrato de persistencia de partidas. Guarda snapshots completos y eventos
// para poder conservar o reconstruir estado del backend.

import 'package:for_core/protocol.dart';

/// Snapshot persistido de una partida.
class PartidaSnapshot {
  const PartidaSnapshot({
    required this.gameId,
    required this.snapshot,
    this.updatedAt,
  });

  final String gameId;
  final Map<String, dynamic> snapshot;
  final DateTime? updatedAt;
}

/// Repositorio de partidas y eventos de juego.
abstract interface class PartidaRepository {
  /// Registra una partida creada con su snapshot inicial.
  Future<void> registrarPartidaCreada({
    required String gameId,
    required int numeroJugadores,
    required Map<String, dynamic> snapshot,
  });

  /// Guarda el ultimo snapshot conocido de una partida.
  Future<void> guardarSnapshot({
    required String gameId,
    required Map<String, dynamic> snapshot,
  });

  /// Registra un evento ocurrido dentro de una partida.
  Future<void> registrarEvento({
    required String gameId,
    required int? playerId,
    required String tipo,
    required Map<String, dynamic> payload,
  });

  /// Carga snapshots persistidos.
  Future<List<PartidaSnapshot>> cargarSnapshots();

  /// Libera recursos del repositorio.
  Future<void> close();
}

/// Implementacion en memoria usada principalmente en tests.
class PartidaRepositoryEnMemoria implements PartidaRepository {
  final Map<String, Map<String, dynamic>> snapshots =
      <String, Map<String, dynamic>>{};
  final Map<String, DateTime> snapshotUpdatedAt = <String, DateTime>{};
  final List<Map<String, dynamic>> eventos = <Map<String, dynamic>>[];

  @override
  Future<void> registrarPartidaCreada({
    required String gameId,
    required int numeroJugadores,
    required Map<String, dynamic> snapshot,
  }) async {
    snapshots[gameId] = snapshot;
    snapshotUpdatedAt[gameId] = DateTime.now().toUtc();
    eventos.add(<String, dynamic>{
      'gameId': gameId,
      'playerId': null,
      'tipo': TipoEventoPartida.gameCreated,
      'payload': <String, dynamic>{'numeroJugadores': numeroJugadores},
    });
  }

  @override
  Future<void> guardarSnapshot({
    required String gameId,
    required Map<String, dynamic> snapshot,
  }) async {
    snapshots[gameId] = snapshot;
    snapshotUpdatedAt[gameId] = DateTime.now().toUtc();
  }

  @override
  Future<void> registrarEvento({
    required String gameId,
    required int? playerId,
    required String tipo,
    required Map<String, dynamic> payload,
  }) async {
    eventos.add(<String, dynamic>{
      'gameId': gameId,
      'playerId': playerId,
      'tipo': tipo,
      'payload': payload,
    });
  }

  @override
  Future<List<PartidaSnapshot>> cargarSnapshots() async {
    return snapshots.entries
        .map(
          (MapEntry<String, Map<String, dynamic>> entry) => PartidaSnapshot(
            gameId: entry.key,
            snapshot: entry.value,
            updatedAt: snapshotUpdatedAt[entry.key],
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> close() async {}
}
