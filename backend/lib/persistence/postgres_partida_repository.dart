// Persistencia PostgreSQL de partidas. Guarda partidas, snapshots JSONB y
// eventos para un backend desplegable con BBDD externa.

import 'dart:convert';

import 'package:postgres/postgres.dart';

import 'partida_repository.dart';

/// Repositorio PostgreSQL para snapshots y eventos de partidas.
class PostgresPartidaRepository implements PartidaRepository {
  PostgresPartidaRepository._(this._connection);

  final PostgreSQLConnection _connection;

  /// Abre una conexion PostgreSQL a partir de una URL.
  static Future<PostgresPartidaRepository> abrirUrl(String dsn) async {
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

    final PostgresPartidaRepository store = PostgresPartidaRepository._(
      connection,
    );
    await store._asegurarEsquema();
    return store;
  }

  /// Crea las tablas necesarias si todavia no existen.
  Future<void> _asegurarEsquema() async {
    await _connection.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    ''');

    await _connection.execute('''
      CREATE TABLE IF NOT EXISTS games (
        game_id TEXT PRIMARY KEY,
        player_count INTEGER NOT NULL CHECK(player_count BETWEEN 2 AND 5),
        status TEXT NOT NULL DEFAULT 'open',
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    ''');

    await _connection.execute('''
      CREATE TABLE IF NOT EXISTS game_snapshots (
        game_id TEXT PRIMARY KEY REFERENCES games(game_id),
        snapshot_json JSONB NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    ''');

    await _connection.execute('''
      CREATE TABLE IF NOT EXISTS game_events (
        id BIGSERIAL PRIMARY KEY,
        game_id TEXT NOT NULL REFERENCES games(game_id),
        player_id INTEGER,
        type TEXT NOT NULL,
        payload_json JSONB NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    ''');

    await _registrarMigracion(1, 'initial_partida_schema');
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
  Future<void> registrarPartidaCreada({
    required String gameId,
    required int numeroJugadores,
    required Map<String, dynamic> snapshot,
  }) async {
    await _connection.query(
      '''
      INSERT INTO games(game_id, player_count, status, updated_at)
      VALUES (@gameId, @playerCount, 'open', NOW())
      ON CONFLICT(game_id) DO NOTHING
      ''',
      substitutionValues: <String, Object?>{
        'gameId': gameId,
        'playerCount': numeroJugadores,
      },
    );
    await guardarSnapshot(gameId: gameId, snapshot: snapshot);
  }

  @override
  Future<void> guardarSnapshot({
    required String gameId,
    required Map<String, dynamic> snapshot,
  }) async {
    await _connection.query(
      '''
      INSERT INTO game_snapshots(game_id, snapshot_json, updated_at)
      VALUES (@gameId, @snapshot::jsonb, NOW())
      ON CONFLICT(game_id) DO UPDATE SET
        snapshot_json = EXCLUDED.snapshot_json,
        updated_at = NOW()
      ''',
      substitutionValues: <String, Object?>{
        'gameId': gameId,
        'snapshot': jsonEncode(snapshot),
      },
    );
    await _connection.query(
      'UPDATE games SET updated_at = NOW() WHERE game_id = @gameId',
      substitutionValues: <String, Object?>{'gameId': gameId},
    );
  }

  @override
  Future<void> registrarEvento({
    required String gameId,
    required int? playerId,
    required String tipo,
    required Map<String, dynamic> payload,
  }) async {
    await _connection.query(
      '''
      INSERT INTO game_events(game_id, player_id, type, payload_json)
      VALUES (@gameId, @playerId, @type, @payload::jsonb)
      ''',
      substitutionValues: <String, Object?>{
        'gameId': gameId,
        'playerId': playerId,
        'type': tipo,
        'payload': jsonEncode(payload),
      },
    );
  }

  @override
  Future<List<PartidaSnapshot>> cargarSnapshots() async {
    final List<List<dynamic>> result = await _connection.query('''
      SELECT game_id, snapshot_json::text, updated_at
      FROM game_snapshots
      ORDER BY game_id ASC
    ''');

    return result
        .map(
          (List<dynamic> row) => PartidaSnapshot(
            gameId: (row[0] as String?) ?? '',
            snapshot: (jsonDecode(row[1] as String) as Map)
                .cast<String, dynamic>(),
            updatedAt: _parseUpdatedAt(row[2]),
          ),
        )
        .where((PartidaSnapshot snapshot) => snapshot.gameId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> close() {
    return _connection.close();
  }

  /// Normaliza valores de fecha recibidos desde PostgreSQL.
  DateTime? _parseUpdatedAt(dynamic value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }
}
