import 'dart:io';

import 'package:prueba_tfg/domain/alias_online.dart';
import 'package:prueba_tfg/domain/entrada_leaderboard.dart';
import 'package:sqlite3/sqlite3.dart';

import 'ranking_global_store.dart';

class RankingGlobalSqlite implements RankingGlobalStore {
  RankingGlobalSqlite._(this._database) {
    _asegurarEsquema();
  }

  final Database _database;

  factory RankingGlobalSqlite.abrirArchivo(String rutaArchivo) {
    final File archivo = File(rutaArchivo);
    archivo.parent.createSync(recursive: true);
    return RankingGlobalSqlite._(sqlite3.open(archivo.path));
  }

  factory RankingGlobalSqlite.enMemoria() {
    return RankingGlobalSqlite._(sqlite3.openInMemory());
  }

  void _asegurarEsquema() {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS leaderboard (
        alias TEXT PRIMARY KEY,
        score INTEGER NOT NULL CHECK(score >= 0),
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
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
    final ResultSet result = _database.select('''
      SELECT alias, score
      FROM leaderboard
      ORDER BY score DESC, alias ASC
      LIMIT 10
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
