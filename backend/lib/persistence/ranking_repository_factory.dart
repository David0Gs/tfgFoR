// Fabrica de repositorios de ranking. Decide SQLite o PostgreSQL a partir de
// la especificacion de BBDD y devuelve tambien una descripcion legible.

import 'dart:io';

import 'postgres_ranking_repository.dart';
import 'sqlite_ranking_repository.dart';
import 'ranking_repository.dart';

/// Abre un repositorio SQLite de ranking.
typedef SqliteStoreOpener = RankingRepository Function(String path);

/// Abre un repositorio PostgreSQL de ranking.
typedef PostgresStoreOpener = Future<RankingRepository> Function(String dsn);

/// Repositorio de ranking junto a una descripcion para logs.
class RankingBackend {
  const RankingBackend({required this.repository, required this.descripcion});

  final RankingRepository repository;
  final String descripcion;
}

/// Crea el backend de ranking adecuado para la cadena de BBDD indicada.
Future<RankingBackend> crearRankingRepositoryDesdeDbSpec(
  String dbSpec, {
  SqliteStoreOpener sqliteStoreOpener = SqliteRankingRepository.abrirArchivo,
  PostgresStoreOpener postgresStoreOpener = PostgresRankingRepository.abrirUrl,
}) async {
  final String dbSpecLimpio = dbSpec.trim();
  if (dbSpecLimpio.isEmpty) {
    throw const FormatException('El parametro --db no puede estar vacio.');
  }

  if (_esPostgresDbSpec(dbSpecLimpio)) {
    final RankingRepository repository = await postgresStoreOpener(
      dbSpecLimpio,
    );
    final Uri uri = Uri.parse(dbSpecLimpio);
    final String databaseName = uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.first;
    return RankingBackend(
      repository: repository,
      descripcion:
          'PostgreSQL ${uri.host}:${uri.hasPort ? uri.port : 5432}/$databaseName',
    );
  }

  final String rutaArchivo = File(dbSpecLimpio).path;
  return RankingBackend(
    repository: sqliteStoreOpener(rutaArchivo),
    descripcion: 'SQLite $rutaArchivo',
  );
}

/// Indica si una especificacion corresponde a PostgreSQL.
bool _esPostgresDbSpec(String dbSpec) {
  return dbSpec.startsWith('postgres://') || dbSpec.startsWith('postgresql://');
}
