import 'package:for_server/config/server_config.dart';
import 'package:test/test.dart';

void main() {
  group('ServerConfig', () {
    test('usa valores por defecto cuando solo se indica db', () {
      final ServerConfig config = ServerConfig.fromArgsAndEnv(<String>[
        '--db=leaderboard.sqlite3',
      ]);

      expect(config.host, '0.0.0.0');
      expect(config.port, 8080);
      expect(config.playerCount, 2);
      expect(config.dbSpec, 'leaderboard.sqlite3');
      expect(config.sqliteFallbackSpec, isEmpty);
      expect(config.restoreRooms, isFalse);
    });

    test('lee variables de entorno', () {
      final ServerConfig config = ServerConfig.fromArgsAndEnv(
        const <String>[],
        environment: const <String, String>{
          ServerConfig.envHost: '127.0.0.1',
          ServerConfig.envPort: '9090',
          ServerConfig.envPlayers: '4',
          ServerConfig.envDb: 'postgres://user:pass@localhost:5432/for_db',
          ServerConfig.envSqliteFallback: 'fallback.sqlite3',
          ServerConfig.envAccessToken: 'casa-token',
          ServerConfig.envRestoreRooms: 'true',
        },
      );

      expect(config.host, '127.0.0.1');
      expect(config.port, 9090);
      expect(config.playerCount, 4);
      expect(config.dbSpec, 'postgres://user:pass@localhost:5432/for_db');
      expect(config.sqliteFallbackSpec, 'fallback.sqlite3');
      expect(config.accessToken, 'casa-token');
      expect(config.restoreRooms, isTrue);
    });

    test('los argumentos tienen prioridad sobre variables de entorno', () {
      final ServerConfig config = ServerConfig.fromArgsAndEnv(
        const <String>[
          '--host=0.0.0.0',
          '--port',
          '8088',
          '--players=3',
          '--db=local.sqlite3',
          '--restore-rooms=false',
        ],
        environment: const <String, String>{
          ServerConfig.envHost: '127.0.0.1',
          ServerConfig.envPort: '9090',
          ServerConfig.envPlayers: '4',
          ServerConfig.envDb: 'remote.sqlite3',
          ServerConfig.envRestoreRooms: 'true',
        },
      );

      expect(config.host, '0.0.0.0');
      expect(config.port, 8088);
      expect(config.playerCount, 3);
      expect(config.dbSpec, 'local.sqlite3');
      expect(config.restoreRooms, isFalse);
    });

    test('valida numero de jugadores y db obligatoria', () {
      final ServerConfig withoutDb = ServerConfig.fromArgsAndEnv(
        const <String>[],
      );
      expect(withoutDb.validar, throwsA(isA<FormatException>()));

      final ServerConfig invalidPlayers = ServerConfig.fromArgsAndEnv(
        const <String>['--players=9', '--db=leaderboard.sqlite3'],
      );
      expect(invalidPlayers.validar, throwsA(isA<FormatException>()));
    });
  });
}
