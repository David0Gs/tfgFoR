import 'dart:io';

import 'package:for_server/config/env_file.dart';
import 'package:for_server/config/server_config.dart';
import 'package:for_server/foundations_server.dart';
import 'package:for_server/logging/server_logger.dart';
import 'package:for_server/persistence/partida_repository.dart';
import 'package:for_server/persistence/partida_repository_factory.dart';
import 'package:for_server/persistence/ranking_repository_factory.dart';
import 'package:for_server/persistence/sqlite_backup_sync.dart';

Future<void> main(List<String> args) async {
  const ServerLogger logger = ServerLogger();
  if (args.contains('--help') || args.contains('-h')) {
    _imprimirUso();
    return;
  }

  final Map<String, String> environment = <String, String>{
    ...await loadServerEnvFile(),
    ...Platform.environment,
  };
  final ServerConfig config = ServerConfig.fromArgsAndEnv(
    args,
    environment: environment,
  );
  try {
    config.validar();
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    _imprimirUso();
    exitCode = 64;
    return;
  }

  final _PersistenciaServidor persistencia;
  try {
    persistencia = await _crearPersistenciaServidor(
      config.dbSpec,
      sqliteFallbackSpec: config.sqliteFallbackSpec,
    );
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    _imprimirUso();
    exitCode = 64;
    return;
  } catch (error) {
    stderr.writeln(
      'No se pudo inicializar la persistencia del servidor: $error',
    );
    exitCode = 1;
    return;
  }

  _imprimirConfiguracion(
    logger,
    config,
    persistencia.rankingBackend.descripcion,
  );

  final FoundationsServer servidor = FoundationsServer(
    defaultPlayerCount: config.playerCount,
    rankingGlobal: persistencia.rankingBackend.repository,
    partidaStore: persistencia.partidaRepository,
    descripcionRanking: persistencia.rankingBackend.descripcion,
    logger: logger,
    accessToken: config.accessToken,
    restoreRoomsOnStart: config.restoreRooms,
  );
  try {
    await servidor.start(host: config.host, port: config.port);
  } finally {
    await servidor.close();
  }
}

void _imprimirUso() {
  stderr.writeln('''
Uso:
  dart run bin/start_server.dart --db=<ruta_sqlite|postgres://...> [opciones]

Opciones:
  --host=<host>                    Host de escucha. Por defecto: 0.0.0.0
  --port=<puerto>                  Puerto de escucha. Por defecto: 8080
  --players=<2-5>                  Jugadores de la partida por defecto. Por defecto: 2
  --db=<ruta|postgres://...>       BBDD principal. Obligatorio.
  --sqlite-fallback=<ruta>         SQLite de respaldo si PostgreSQL falla.
  --access-token=<token>           Token opcional para crear/unirse a partidas.
  --restore-rooms=<true|false>     Restaura snapshots como salas al arrancar. Por defecto: false.
  --help                           Muestra esta ayuda.

Variables de entorno equivalentes:
  FOR_HOST
  FOR_PORT
  FOR_PLAYERS
  FOR_DB
  FOR_SQLITE_FALLBACK
  FOR_ACCESS_TOKEN
  FOR_RESTORE_ROOMS

Si existe un archivo .env junto al servidor, tambien se carga automaticamente.
Los argumentos CLI tienen prioridad sobre las variables de entorno.
''');
}

void _imprimirConfiguracion(
  ServerLogger logger,
  ServerConfig config,
  String rankingDescripcion,
) {
  logger.info('Configuracion del servidor:');
  logger.info('  Host: ${config.host}');
  logger.info('  Puerto: ${config.port}');
  logger.info('  Jugadores por defecto: ${config.playerCount}');
  logger.info('  Persistencia: $rankingDescripcion');
  logger.info(
    '  Token de acceso: ${config.accessToken.isEmpty ? 'desactivado' : 'activado'}',
  );
  if (config.sqliteFallbackSpec.isNotEmpty) {
    logger.info('  SQLite fallback: ${config.sqliteFallbackSpec}');
  }
  logger.info(
    '  Restaurar salas al arrancar: ${config.restoreRooms ? 'si' : 'no'}',
  );
}

class _PersistenciaServidor {
  const _PersistenciaServidor({
    required this.rankingBackend,
    required this.partidaRepository,
  });

  final RankingBackend rankingBackend;
  final PartidaRepository partidaRepository;
}

Future<_PersistenciaServidor> _crearPersistenciaServidor(
  String dbSpec, {
  required String sqliteFallbackSpec,
}) async {
  try {
    final _PersistenciaServidor persistencia = await _abrirPersistenciaServidor(
      dbSpec,
    );
    if (_esPostgresDbSpec(dbSpec) && sqliteFallbackSpec.isNotEmpty) {
      await _sincronizarSqliteFallback(
        persistencia,
        sqliteFallbackSpec: sqliteFallbackSpec,
      );
    }
    return persistencia;
  } on FormatException {
    rethrow;
  } catch (error) {
    if (!_esPostgresDbSpec(dbSpec) || sqliteFallbackSpec.isEmpty) {
      rethrow;
    }

    const ServerLogger().warning(
      'No se pudo conectar con PostgreSQL ($error). '
      'Se usara SQLite como respaldo: $sqliteFallbackSpec',
    );
    return _abrirPersistenciaServidor(sqliteFallbackSpec);
  }
}

Future<void> _sincronizarSqliteFallback(
  _PersistenciaServidor persistenciaPrincipal, {
  required String sqliteFallbackSpec,
}) async {
  if (_esPostgresDbSpec(sqliteFallbackSpec)) {
    return;
  }

  _PersistenciaServidor? persistenciaBackup;
  try {
    persistenciaBackup = await _abrirPersistenciaServidor(sqliteFallbackSpec);
    final BidirectionalBackupSyncResult result =
        await sincronizarBackupBidireccional(
          primaryRanking: persistenciaPrincipal.rankingBackend.repository,
          primaryPartidas: persistenciaPrincipal.partidaRepository,
          sqliteRanking: persistenciaBackup.rankingBackend.repository,
          sqlitePartidas: persistenciaBackup.partidaRepository,
        );
    const ServerLogger().info(
      'Sincronizacion SQLite/PostgreSQL: '
      '${result.sqliteToPrimary.rankingEntries} ranking y '
      '${result.sqliteToPrimary.snapshots} snapshots subidos a PostgreSQL; '
      '${result.primaryToSqlite.rankingEntries} ranking y '
      '${result.primaryToSqlite.snapshots} snapshots bajados a SQLite.',
    );
  } catch (error) {
    const ServerLogger().warning(
      'No se pudo actualizar el backup SQLite ($sqliteFallbackSpec): $error',
    );
  } finally {
    await persistenciaBackup?.partidaRepository.close();
    await persistenciaBackup?.rankingBackend.repository.close();
  }
}

Future<_PersistenciaServidor> _abrirPersistenciaServidor(String dbSpec) async {
  final RankingBackend rankingBackend = await crearRankingRepositoryDesdeDbSpec(
    dbSpec,
  );
  try {
    final PartidaRepository partidaRepository =
        await crearPartidaRepositoryDesdeDbSpec(dbSpec);
    return _PersistenciaServidor(
      rankingBackend: rankingBackend,
      partidaRepository: partidaRepository,
    );
  } catch (_) {
    await rankingBackend.repository.close();
    rethrow;
  }
}

bool _esPostgresDbSpec(String dbSpec) {
  final String dbSpecLimpio = dbSpec.trim();
  return dbSpecLimpio.startsWith('postgres://') ||
      dbSpecLimpio.startsWith('postgresql://');
}
