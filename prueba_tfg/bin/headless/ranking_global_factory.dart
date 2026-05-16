import 'dart:io';

import 'ranking_global_postgres.dart';
import 'ranking_global_sqlite.dart';
import 'ranking_global_store.dart';

typedef SqliteStoreOpener = RankingGlobalStore Function(String path);
typedef PostgresStoreOpener = Future<RankingGlobalStore> Function(String dsn);

class RankingGlobalBackend {
  const RankingGlobalBackend({required this.store, required this.descripcion});

  final RankingGlobalStore store;
  final String descripcion;
}

Future<RankingGlobalBackend> crearRankingGlobalDesdeDbSpec(
  String dbSpec, {
  SqliteStoreOpener sqliteStoreOpener = RankingGlobalSqlite.abrirArchivo,
  PostgresStoreOpener postgresStoreOpener = RankingGlobalPostgres.abrirUrl,
}) async {
  final String dbSpecLimpio = dbSpec.trim();
  if (dbSpecLimpio.isEmpty) {
    throw const FormatException('El parametro --db no puede estar vacio.');
  }

  if (_esPostgresDbSpec(dbSpecLimpio)) {
    final RankingGlobalStore store = await postgresStoreOpener(dbSpecLimpio);
    final Uri uri = Uri.parse(dbSpecLimpio);
    final String databaseName = uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.first;
    return RankingGlobalBackend(
      store: store,
      descripcion:
          'PostgreSQL ${uri.host}:${uri.hasPort ? uri.port : 5432}/$databaseName',
    );
  }

  final String rutaArchivo = File(dbSpecLimpio).path;
  return RankingGlobalBackend(
    store: sqliteStoreOpener(rutaArchivo),
    descripcion: 'SQLite $rutaArchivo',
  );
}

bool _esPostgresDbSpec(String dbSpec) {
  return dbSpec.startsWith('postgres://') || dbSpec.startsWith('postgresql://');
}
