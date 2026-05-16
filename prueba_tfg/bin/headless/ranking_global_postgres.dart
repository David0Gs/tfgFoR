import 'package:prueba_tfg/domain/alias_online.dart';
import 'package:prueba_tfg/domain/entrada_leaderboard.dart';
import 'package:postgres/postgres.dart';

import 'ranking_global_store.dart';

class RankingGlobalPostgres implements RankingGlobalStore {
  RankingGlobalPostgres._(this._connection);

  final PostgreSQLConnection _connection;

  static Future<RankingGlobalPostgres> abrirUrl(String dsn) async {
    final Uri uri = Uri.parse(dsn.trim());
    if (uri.scheme != 'postgres' && uri.scheme != 'postgresql') {
      throw FormatException(
        'La URL de PostgreSQL debe empezar por postgres:// o postgresql://.',
      );
    }

    final String databaseName = uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.first;
    if (databaseName.isEmpty) {
      throw const FormatException(
        'La URL de PostgreSQL debe incluir nombre de base de datos.',
      );
    }

    final String username = uri.userInfo.contains(':')
        ? uri.userInfo.split(':').first
        : uri.userInfo;
    final String password = uri.userInfo.contains(':')
        ? uri.userInfo.split(':').skip(1).join(':')
        : '';

    final PostgreSQLConnection connection = PostgreSQLConnection(
      uri.host,
      uri.hasPort ? uri.port : 5432,
      databaseName,
      username: username.isEmpty ? null : username,
      password: password.isEmpty ? null : password,
    );

    await connection.open();

    final RankingGlobalPostgres ranking = RankingGlobalPostgres._(connection);
    await ranking._asegurarEsquema();
    return ranking;
  }

  Future<void> _asegurarEsquema() {
    return _connection.execute('''
      CREATE TABLE IF NOT EXISTS leaderboard (
        alias TEXT PRIMARY KEY,
        score INTEGER NOT NULL CHECK(score >= 0),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    ''');
  }

  @override
  Future<bool> registrarPuntuacionMaxima({
    required String alias,
    required int puntuacion,
  }) async {
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

    final List<List<dynamic>> actual = await _connection.query(
      'SELECT score FROM leaderboard WHERE alias = @alias',
      substitutionValues: <String, Object?>{'alias': aliasNormalizado},
    );
    if (actual.isNotEmpty) {
      final int puntuacionActual = (actual.first.first as int?) ?? 0;
      if (puntuacionActual >= puntuacion) {
        return false;
      }
    }

    await _connection.query(
      '''
      INSERT INTO leaderboard(alias, score, updated_at)
      VALUES (@alias, @score, NOW())
      ON CONFLICT(alias) DO UPDATE SET
        score = EXCLUDED.score,
        updated_at = NOW()
      WHERE EXCLUDED.score > leaderboard.score
      ''',
      substitutionValues: <String, Object?>{
        'alias': aliasNormalizado,
        'score': puntuacion,
      },
    );

    return true;
  }

  @override
  Future<List<EntradaClasificacion>> cargarTop10() async {
    final List<List<dynamic>> result = await _connection.query('''
      SELECT alias, score
      FROM leaderboard
      ORDER BY score DESC, alias ASC
      LIMIT 10
    ''');

    return result
        .map(
          (List<dynamic> row) => EntradaClasificacion(
            alias: (row[0] as String?) ?? '',
            puntuacion: (row[1] as int?) ?? 0,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> close() {
    return _connection.close();
  }
}
