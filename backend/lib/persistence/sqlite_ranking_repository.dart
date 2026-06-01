// Persistencia SQLite del leaderboard global. Mantiene una puntuacion maxima
// por alias y permite consultar top 10 o ranking completo.

import 'dart:io';

import 'package:for_core/core.dart';
import 'package:sqlite3/sqlite3.dart';

import 'ranking_repository.dart';

/// Repositorio SQLite de ranking.
class SqliteRankingRepository implements RankingRepository {
  SqliteRankingRepository._(this._database) {
    _asegurarEsquema();
  }

  final Database _database;

  /// Abre o crea un archivo SQLite de ranking.
  factory SqliteRankingRepository.abrirArchivo(String rutaArchivo) {
    final File archivo = File(rutaArchivo);
    archivo.parent.createSync(recursive: true);
    return SqliteRankingRepository._(sqlite3.open(archivo.path));
  }

  /// Crea un ranking SQLite en memoria para tests.
  factory SqliteRankingRepository.enMemoria() {
    return SqliteRankingRepository._(sqlite3.openInMemory());
  }

  /// Crea las tablas necesarias si todavia no existen.
  void _asegurarEsquema() {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    _database.execute('''
      CREATE TABLE IF NOT EXISTS leaderboard (
        alias TEXT PRIMARY KEY,
        score INTEGER NOT NULL CHECK(score >= 0),
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    _registrarMigracion(1, 'initial_ranking_schema');
  }

  /// Registra una migracion aplicada de forma idempotente.
  void _registrarMigracion(int version, String name) {
    _database.execute(
      '''
      INSERT INTO schema_migrations(version, name, applied_at)
      VALUES (?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(version) DO NOTHING
      ''',
      <Object?>[version, name],
    );
  }

  @override
  Future<bool> registrarPuntuacionMaxima({
    required String alias,
    required int puntuacion,
  }) {
    final String aliasNormalizado = AliasOnline.normalizar(alias);
    final String? errorAlias = AliasOnline.mensajeError(aliasNormalizado);
    if (errorAlias != null) {
      throw ArgumentError.value(alias, 'alias', errorAlias);
    }
    if (puntuacion < 0) {
      throw ArgumentError.value(
        puntuacion,
        'puntuacion',
        'La puntuacion no puede ser negativa.',
      );
    }

    final ResultSet actual = _database.select(
      'SELECT score FROM leaderboard WHERE alias = ?',
      <Object?>[aliasNormalizado],
    );
    if (actual.isNotEmpty) {
      final int puntuacionActual = actual.first['score'] as int? ?? 0;
      if (puntuacionActual >= puntuacion) {
        return Future<bool>.value(false);
      }
    }

    _database.execute(
      '''
      INSERT INTO leaderboard(alias, score, updated_at)
      VALUES (?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(alias) DO UPDATE SET
        score = excluded.score,
        updated_at = CURRENT_TIMESTAMP
      WHERE excluded.score > leaderboard.score
      ''',
      <Object?>[aliasNormalizado, puntuacion],
    );
    return Future<bool>.value(true);
  }

  @override
  Future<List<EntradaClasificacion>> cargarTop10() {
    return _cargarRanking(limit: 10);
  }

  @override
  Future<List<EntradaClasificacion>> cargarRankingCompleto() {
    return _cargarRanking();
  }

  /// Carga ranking ordenado con limite opcional.
  Future<List<EntradaClasificacion>> _cargarRanking({int? limit}) {
    final ResultSet result = _database.select('''
      SELECT alias, score
      FROM leaderboard
      ORDER BY score DESC, alias ASC
      ${limit == null ? '' : 'LIMIT $limit'}
      ''');

    return Future<List<EntradaClasificacion>>.value(
      result
          .map(
            (Row row) => EntradaClasificacion(
              alias: row['alias'] as String? ?? '',
              puntuacion: row['score'] as int? ?? 0,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<void> close() async {
    _database.dispose();
  }
}
