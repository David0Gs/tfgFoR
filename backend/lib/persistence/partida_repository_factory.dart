// Fabrica de repositorios de partida. Decide SQLite o PostgreSQL a partir de
// la especificacion de BBDD recibida en configuracion.

import 'dart:io';

import 'partida_repository.dart';
import 'postgres_partida_repository.dart';
import 'sqlite_partida_repository.dart';

/// Abre un repositorio SQLite de partidas.
typedef SqlitePartidaRepositoryOpener = PartidaRepository Function(String path);

/// Abre un repositorio PostgreSQL de partidas.
typedef PostgresPartidaRepositoryOpener =
    Future<PartidaRepository> Function(String dsn);

/// Crea el repositorio de partidas adecuado para la cadena de BBDD indicada.
Future<PartidaRepository> crearPartidaRepositoryDesdeDbSpec(
  String dbSpec, {
  SqlitePartidaRepositoryOpener sqliteRepositoryOpener =
      SqlitePartidaRepository.abrirArchivo,
  PostgresPartidaRepositoryOpener postgresStoreOpener =
      PostgresPartidaRepository.abrirUrl,
}) {
  final String dbSpecLimpio = dbSpec.trim();
  if (dbSpecLimpio.isEmpty) {
    throw const FormatException('El parametro --db no puede estar vacio.');
  }

  if (_esPostgresDbSpec(dbSpecLimpio)) {
    return postgresStoreOpener(dbSpecLimpio);
  }

  return Future<PartidaRepository>.value(
    sqliteRepositoryOpener(File(dbSpecLimpio).path),
  );
}

/// Indica si una especificacion corresponde a PostgreSQL.
bool _esPostgresDbSpec(String dbSpec) {
  return dbSpec.startsWith('postgres://') || dbSpec.startsWith('postgresql://');
}
