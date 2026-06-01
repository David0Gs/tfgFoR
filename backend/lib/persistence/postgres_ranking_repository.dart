// Persistencia PostgreSQL del leaderboard global. Mantiene una puntuacion
// maxima por alias usando una base de datos externa.

import 'package:for_core/core.dart';
import 'package:postgres/postgres.dart';

import 'ranking_repository.dart';

/// Repositorio PostgreSQL de ranking.
class PostgresRankingRepository implements RankingRepository {
  PostgresRankingRepository._(this._connection);

  final PostgreSQLConnection _connection;

  /// Abre una conexion PostgreSQL a partir de una URL.
  static Future<PostgresRankingRepository> abrirUrl(String dsn) async {
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

    final PostgresRankingRepository ranking = PostgresRankingRepository._(
      connection,
    );
    await ranking._asegurarEsquema();
    return ranking;
  }

  /// Crea las tablas necesarias si todavia no existen.
  Future<void> _asegurarEsquema() {
    return _connection
        .execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS leaderboard (
        alias TEXT PRIMARY KEY,
        score INTEGER NOT NULL CHECK(score >= 0),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    ''')
        .then((_) => _registrarMigracion(1, 'initial_ranking_schema'));
  }

  /// Registra una migracion aplicada de forma idempotente.
  Future<void> _registrarMigracion(int version, String name) {
    return _connection.query(
      '''
      INSERT INTO schema_migrations(version, name, applied_at)
      VALUES (@version, @name, NOW())
      ON CONFLICT(version) DO NOTHING
      ''',
      substitutionValues: <String, Object?>{'version': version, 'name': name},
    );
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
    return _cargarRanking(limit: 10);
  }

  @override
  Future<List<EntradaClasificacion>> cargarRankingCompleto() {
    return _cargarRanking();
  }

  /// Carga ranking ordenado con limite opcional.
  Future<List<EntradaClasificacion>> _cargarRanking({int? limit}) async {
    final List<List<dynamic>> result = await _connection.query('''
      SELECT alias, score
      FROM leaderboard
      ORDER BY score DESC, alias ASC
      ${limit == null ? '' : 'LIMIT $limit'}
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
