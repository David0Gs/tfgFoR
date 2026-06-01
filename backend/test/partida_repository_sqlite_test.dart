import 'dart:convert';
import 'dart:io';

import 'package:for_core/protocol.dart';
import 'package:for_server/persistence/sqlite_partida_repository.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('SqlitePartidaRepository', () {
    late Directory tempDir;
    late File databaseFile;
    late SqlitePartidaRepository repository;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'for_partida_repository_test_',
      );
      databaseFile = File('${tempDir.path}/partidas.sqlite3');
      repository = SqlitePartidaRepository.abrirArchivo(databaseFile.path);
    });

    tearDown(() async {
      await repository.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('registra partida creada y snapshot inicial', () async {
      await repository.registrarPartidaCreada(
        gameId: 'game_0001',
        numeroJugadores: 3,
        snapshot: <String, dynamic>{
          'currentPlayer': 0,
          'players': <String>['ABC', 'ROM', 'FOR'],
        },
      );

      final Database db = sqlite3.open(databaseFile.path);
      try {
        final Row game = db.select(
          'SELECT game_id, player_count, status FROM games WHERE game_id = ?',
          <Object?>['game_0001'],
        ).single;
        expect(game['game_id'], 'game_0001');
        expect(game['player_count'], 3);
        expect(game['status'], 'open');

        final Row snapshot = db.select(
          'SELECT snapshot_json FROM game_snapshots WHERE game_id = ?',
          <Object?>['game_0001'],
        ).single;
        final Map<String, dynamic> snapshotJson =
            (jsonDecode(snapshot['snapshot_json'] as String) as Map)
                .cast<String, dynamic>();
        expect(snapshotJson['currentPlayer'], 0);
        expect(snapshotJson['players'], <String>['ABC', 'ROM', 'FOR']);
      } finally {
        db.dispose();
      }
    });

    test('guardarSnapshot sobrescribe el snapshot anterior', () async {
      await repository.registrarPartidaCreada(
        gameId: 'game_0001',
        numeroJugadores: 2,
        snapshot: <String, dynamic>{'turn': 0},
      );

      await repository.guardarSnapshot(
        gameId: 'game_0001',
        snapshot: <String, dynamic>{'turn': 4, 'finished': false},
      );

      final Database db = sqlite3.open(databaseFile.path);
      try {
        final Row snapshot = db.select(
          'SELECT snapshot_json FROM game_snapshots WHERE game_id = ?',
          <Object?>['game_0001'],
        ).single;
        final Map<String, dynamic> snapshotJson =
            (jsonDecode(snapshot['snapshot_json'] as String) as Map)
                .cast<String, dynamic>();
        expect(snapshotJson['turn'], 4);
        expect(snapshotJson['finished'], isFalse);
      } finally {
        db.dispose();
      }
    });

    test('registra eventos de partida', () async {
      await repository.registrarPartidaCreada(
        gameId: 'game_0001',
        numeroJugadores: 2,
        snapshot: <String, dynamic>{'turn': 0},
      );

      await repository.registrarEvento(
        gameId: 'game_0001',
        playerId: 1,
        tipo: TipoAccionRemota.income,
        payload: <String, dynamic>{'amount': 5},
      );

      final Database db = sqlite3.open(databaseFile.path);
      try {
        final Row event = db
            .select(
              '''
              SELECT game_id, player_id, type, payload_json
              FROM game_events
              WHERE game_id = ?
              ''',
              <Object?>['game_0001'],
            )
            .single;
        expect(event['game_id'], 'game_0001');
        expect(event['player_id'], 1);
        expect(event['type'], TipoAccionRemota.income);

        final Map<String, dynamic> payload =
            (jsonDecode(event['payload_json'] as String) as Map)
                .cast<String, dynamic>();
        expect(payload['amount'], 5);
      } finally {
        db.dispose();
      }
    });

    test('carga snapshots persistidos', () async {
      await repository.registrarPartidaCreada(
        gameId: 'game_0009',
        numeroJugadores: 2,
        snapshot: <String, dynamic>{'numeroJugadores': 2},
      );

      final snapshots = await repository.cargarSnapshots();

      expect(snapshots, hasLength(1));
      expect(snapshots.single.gameId, 'game_0009');
      expect(snapshots.single.snapshot['numeroJugadores'], 2);
    });
  });
}
