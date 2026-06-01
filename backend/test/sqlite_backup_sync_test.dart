import 'package:for_server/persistence/partida_repository.dart';
import 'package:for_server/persistence/sqlite_backup_sync.dart';
import 'package:for_server/persistence/sqlite_ranking_repository.dart';
import 'package:test/test.dart';

void main() {
  group('sincronizarBackupSqlite', () {
    test('copia ranking y snapshots disponibles', () async {
      final SqliteRankingRepository sourceRanking =
          SqliteRankingRepository.enMemoria();
      final SqliteRankingRepository targetRanking =
          SqliteRankingRepository.enMemoria();
      final PartidaRepositoryEnMemoria sourcePartidas =
          PartidaRepositoryEnMemoria();
      final PartidaRepositoryEnMemoria targetPartidas =
          PartidaRepositoryEnMemoria();
      addTearDown(sourceRanking.close);
      addTearDown(targetRanking.close);

      await sourceRanking.registrarPuntuacionMaxima(
        alias: 'ABC',
        puntuacion: 42,
      );
      for (int index = 0; index < 12; index++) {
        await sourceRanking.registrarPuntuacionMaxima(
          alias: 'A${index.toString().padLeft(2, '0')}',
          puntuacion: index,
        );
      }
      await sourcePartidas.registrarPartidaCreada(
        gameId: 'game_0001',
        numeroJugadores: 2,
        snapshot: <String, dynamic>{
          'numeroJugadores': 2,
          'players': const <dynamic>[],
        },
      );

      final SqliteBackupSyncResult result = await sincronizarBackupSqlite(
        sourceRanking: sourceRanking,
        sourcePartidas: sourcePartidas,
        targetRanking: targetRanking,
        targetPartidas: targetPartidas,
      );

      expect(result.rankingEntries, 13);
      expect(result.snapshots, 1);
      expect(await targetRanking.cargarRankingCompleto(), hasLength(13));
      expect(targetPartidas.snapshots, contains('game_0001'));
    });

    test('sincroniza SQLite y principal en los dos sentidos', () async {
      final SqliteRankingRepository primaryRanking =
          SqliteRankingRepository.enMemoria();
      final SqliteRankingRepository sqliteRanking =
          SqliteRankingRepository.enMemoria();
      final PartidaRepositoryEnMemoria primaryPartidas =
          PartidaRepositoryEnMemoria();
      final PartidaRepositoryEnMemoria sqlitePartidas =
          PartidaRepositoryEnMemoria();
      addTearDown(primaryRanking.close);
      addTearDown(sqliteRanking.close);

      await primaryRanking.registrarPuntuacionMaxima(
        alias: 'PGS',
        puntuacion: 80,
      );
      await sqliteRanking.registrarPuntuacionMaxima(
        alias: 'SQL',
        puntuacion: 65,
      );
      await primaryPartidas.registrarPartidaCreada(
        gameId: 'game_postgres',
        numeroJugadores: 2,
        snapshot: <String, dynamic>{'numeroJugadores': 2},
      );
      await sqlitePartidas.registrarPartidaCreada(
        gameId: 'game_sqlite',
        numeroJugadores: 3,
        snapshot: <String, dynamic>{'numeroJugadores': 3},
      );

      final BidirectionalBackupSyncResult result =
          await sincronizarBackupBidireccional(
            primaryRanking: primaryRanking,
            primaryPartidas: primaryPartidas,
            sqliteRanking: sqliteRanking,
            sqlitePartidas: sqlitePartidas,
          );

      expect(result.sqliteToPrimary.rankingEntries, 1);
      expect(result.sqliteToPrimary.snapshots, 1);
      expect(result.primaryToSqlite.rankingEntries, 2);
      expect(result.primaryToSqlite.snapshots, 1);
      expect(await primaryRanking.cargarRankingCompleto(), hasLength(2));
      expect(await sqliteRanking.cargarRankingCompleto(), hasLength(2));
      expect(primaryPartidas.snapshots, contains('game_sqlite'));
      expect(sqlitePartidas.snapshots, contains('game_postgres'));
    });
  });
}
