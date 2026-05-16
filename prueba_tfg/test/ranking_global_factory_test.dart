import 'package:flutter_test/flutter_test.dart';
import 'package:prueba_tfg/domain/entrada_leaderboard.dart';
import '../bin/headless/ranking_global_factory.dart';
import '../bin/headless/ranking_global_store.dart';

class _FakeStore implements RankingGlobalStore {
  @override
  Future<List<EntradaClasificacion>> cargarTop10() async {
    return const <EntradaClasificacion>[];
  }

  @override
  Future<void> close() async {}

  @override
  Future<bool> registrarPuntuacionMaxima({
    required String alias,
    required int puntuacion,
  }) async {
    return true;
  }
}

void main() {
  test('lanza error si --db esta vacio', () async {
    await expectLater(
      () => crearRankingGlobalDesdeDbSpec('   '),
      throwsA(isA<FormatException>()),
    );
  });

  test('usa sqlite cuando dbSpec no es URL de postgres', () async {
    final _FakeStore sqliteStore = _FakeStore();

    final RankingGlobalBackend backend = await crearRankingGlobalDesdeDbSpec(
      'bin/leaderboard.sqlite3',
      sqliteStoreOpener: (_) => sqliteStore,
      postgresStoreOpener: (_) async =>
          throw StateError('no debe usar postgres'),
    );

    expect(backend.store, same(sqliteStore));
    expect(backend.descripcion.startsWith('SQLite '), isTrue);
  });

  test('usa postgres cuando dbSpec es URL postgres', () async {
    final _FakeStore postgresStore = _FakeStore();

    final RankingGlobalBackend backend = await crearRankingGlobalDesdeDbSpec(
      'postgres://user:pass@localhost:5432/for_db',
      sqliteStoreOpener: (_) => throw StateError('no debe usar sqlite'),
      postgresStoreOpener: (_) async => postgresStore,
    );

    expect(backend.store, same(postgresStore));
    expect(backend.descripcion.startsWith('PostgreSQL '), isTrue);
    expect(backend.descripcion.contains('/for_db'), isTrue);
  });
}
