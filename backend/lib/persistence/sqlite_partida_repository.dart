// Persistencia SQLite de partidas. Guarda salas, snapshots JSON y eventos en
// tablas locales para desarrollo, fallback o servidor casero sencillo.

import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'partida_repository.dart';

/// Repositorio SQLite para snapshots y eventos de partidas.
class SqlitePartidaRepository implements PartidaRepository {
  SqlitePartidaRepository._(this._database) {
    _asegurarEsquema();
  }

  final Database _database;

  /// Abre o crea un archivo SQLite de partidas.
  factory SqlitePartidaRepository.abrirArchivo(String rutaArchivo) {
    final File archivo = File(rutaArchivo);
    archivo.parent.createSync(recursive: true);
    return SqlitePartidaRepository._(sqlite3.open(archivo.path));
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
      CREATE TABLE IF NOT EXISTS games (
        game_id TEXT PRIMARY KEY,
        player_count INTEGER NOT NULL CHECK(player_count BETWEEN 2 AND 5),
        status TEXT NOT NULL DEFAULT 'open',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    _database.execute('''
      CREATE TABLE IF NOT EXISTS game_snapshots (
        game_id TEXT PRIMARY KEY,
        snapshot_json TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(game_id) REFERENCES games(game_id)
      )
    ''');

    _database.execute('''
      CREATE TABLE IF NOT EXISTS game_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id TEXT NOT NULL,
        player_id INTEGER,
        type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(game_id) REFERENCES games(game_id)
      )
    ''');

    _registrarMigracion(1, 'initial_partida_schema');
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
  Future<void> registrarPartidaCreada({
    required String gameId,
    required int numeroJugadores,
    required Map<String, dynamic> snapshot,
  }) async {
    _database.execute(
      '''
      INSERT INTO games(game_id, player_count, status, updated_at)
      VALUES (?, ?, 'open', CURRENT_TIMESTAMP)
      ON CONFLICT(game_id) DO NOTHING
      ''',
      <Object?>[gameId, numeroJugadores],
    );
    await guardarSnapshot(gameId: gameId, snapshot: snapshot);
  }

  @override
  Future<void> guardarSnapshot({
    required String gameId,
    required Map<String, dynamic> snapshot,
  }) async {
    _database.execute(
      '''
      INSERT INTO game_snapshots(game_id, snapshot_json, updated_at)
      VALUES (?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(game_id) DO UPDATE SET
        snapshot_json = excluded.snapshot_json,
        updated_at = CURRENT_TIMESTAMP
      ''',
      <Object?>[gameId, jsonEncode(snapshot)],
    );
    _database.execute(
      'UPDATE games SET updated_at = CURRENT_TIMESTAMP WHERE game_id = ?',
      <Object?>[gameId],
    );
  }

  @override
  Future<void> registrarEvento({
    required String gameId,
    required int? playerId,
    required String tipo,
    required Map<String, dynamic> payload,
  }) async {
    _database.execute(
      '''
      INSERT INTO game_events(game_id, player_id, type, payload_json)
      VALUES (?, ?, ?, ?)
      ''',
      <Object?>[gameId, playerId, tipo, jsonEncode(payload)],
    );
  }

  @override
  Future<List<PartidaSnapshot>> cargarSnapshots() async {
    final ResultSet result = _database.select('''
      SELECT game_id, snapshot_json
        , updated_at
      FROM game_snapshots
      ORDER BY game_id ASC
    ''');

    return result
        .map(
          (Row row) => PartidaSnapshot(
            gameId: row['game_id'] as String? ?? '',
            snapshot: (jsonDecode(row['snapshot_json'] as String) as Map)
                .cast<String, dynamic>(),
            updatedAt: DateTime.tryParse(
              (row['updated_at'] as String?) ?? '',
            )?.toUtc(),
          ),
        )
        .where((PartidaSnapshot snapshot) => snapshot.gameId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> close() async {
    _database.dispose();
  }
}
