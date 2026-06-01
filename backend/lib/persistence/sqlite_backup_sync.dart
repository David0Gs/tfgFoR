// Sincronizacion entre repositorio principal y SQLite de respaldo. Copia
// ranking y snapshots en ambos sentidos para que el fallback tenga datos y para
// subir datos locales cuando PostgreSQL vuelve.

import 'package:for_core/core.dart';

import 'partida_repository.dart';
import 'ranking_repository.dart';

/// Resultado de copiar datos entre dos repositorios.
class SqliteBackupSyncResult {
  const SqliteBackupSyncResult({
    required this.rankingEntries,
    required this.snapshots,
  });

  final int rankingEntries;
  final int snapshots;
}

/// Resultado completo de sincronizar en ambos sentidos.
class BidirectionalBackupSyncResult {
  const BidirectionalBackupSyncResult({
    required this.sqliteToPrimary,
    required this.primaryToSqlite,
  });

  final SqliteBackupSyncResult sqliteToPrimary;
  final SqliteBackupSyncResult primaryToSqlite;

  /// Total de entradas de ranking procesadas en ambos sentidos.
  int get totalRankingEntries =>
      sqliteToPrimary.rankingEntries + primaryToSqlite.rankingEntries;

  /// Total de snapshots copiados en ambos sentidos.
  int get totalSnapshots =>
      sqliteToPrimary.snapshots + primaryToSqlite.snapshots;
}

/// Sincroniza primero SQLite hacia principal y despues principal hacia SQLite.
Future<BidirectionalBackupSyncResult> sincronizarBackupBidireccional({
  required RankingRepository primaryRanking,
  required PartidaRepository primaryPartidas,
  required RankingRepository sqliteRanking,
  required PartidaRepository sqlitePartidas,
}) async {
  final SqliteBackupSyncResult sqliteToPrimary = await sincronizarBackupSqlite(
    sourceRanking: sqliteRanking,
    sourcePartidas: sqlitePartidas,
    targetRanking: primaryRanking,
    targetPartidas: primaryPartidas,
  );
  final SqliteBackupSyncResult primaryToSqlite = await sincronizarBackupSqlite(
    sourceRanking: primaryRanking,
    sourcePartidas: primaryPartidas,
    targetRanking: sqliteRanking,
    targetPartidas: sqlitePartidas,
  );

  return BidirectionalBackupSyncResult(
    sqliteToPrimary: sqliteToPrimary,
    primaryToSqlite: primaryToSqlite,
  );
}

/// Copia ranking y snapshots desde un origen hacia un destino.
Future<SqliteBackupSyncResult> sincronizarBackupSqlite({
  required RankingRepository sourceRanking,
  required PartidaRepository sourcePartidas,
  required RankingRepository targetRanking,
  required PartidaRepository targetPartidas,
}) async {
  final List<EntradaClasificacion> ranking = await sourceRanking
      .cargarRankingCompleto();
  for (final EntradaClasificacion entrada in ranking) {
    await targetRanking.registrarPuntuacionMaxima(
      alias: entrada.alias,
      puntuacion: entrada.puntuacion,
    );
  }

  final List<PartidaSnapshot> snapshots = await sourcePartidas
      .cargarSnapshots();
  final Map<String, PartidaSnapshot> targetSnapshotsById =
      <String, PartidaSnapshot>{
        for (final PartidaSnapshot snapshot
            in await targetPartidas.cargarSnapshots())
          snapshot.gameId: snapshot,
      };
  int snapshotsCopiados = 0;
  for (final PartidaSnapshot snapshot in snapshots) {
    final PartidaSnapshot? targetSnapshot =
        targetSnapshotsById[snapshot.gameId];
    if (!_debeCopiarSnapshot(snapshot, targetSnapshot)) {
      continue;
    }

    final int? numeroJugadores = _numeroJugadoresDesdeSnapshot(
      snapshot.snapshot,
    );
    if (numeroJugadores == null) {
      continue;
    }

    await targetPartidas.registrarPartidaCreada(
      gameId: snapshot.gameId,
      numeroJugadores: numeroJugadores,
      snapshot: snapshot.snapshot,
    );
    snapshotsCopiados++;
  }

  return SqliteBackupSyncResult(
    rankingEntries: ranking.length,
    snapshots: snapshotsCopiados,
  );
}

/// Decide si un snapshot origen es mas nuevo o falta en destino.
bool _debeCopiarSnapshot(PartidaSnapshot source, PartidaSnapshot? target) {
  if (target == null) {
    return true;
  }

  final DateTime? sourceUpdatedAt = source.updatedAt;
  final DateTime? targetUpdatedAt = target.updatedAt;
  if (sourceUpdatedAt == null || targetUpdatedAt == null) {
    return true;
  }

  return sourceUpdatedAt.isAfter(targetUpdatedAt);
}

/// Extrae el numero de jugadores desde un snapshot de partida.
int? _numeroJugadoresDesdeSnapshot(Map<String, dynamic> snapshot) {
  final Object? rawNumeroJugadores = snapshot['numeroJugadores'];
  if (rawNumeroJugadores is int &&
      rawNumeroJugadores >= 2 &&
      rawNumeroJugadores <= 5) {
    return rawNumeroJugadores;
  }

  final Object? rawPlayers = snapshot['players'];
  if (rawPlayers is List && rawPlayers.length >= 2 && rawPlayers.length <= 5) {
    return rawPlayers.length;
  }

  return null;
}
