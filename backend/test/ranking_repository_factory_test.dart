import 'package:for_core/core.dart';
import 'package:for_server/persistence/ranking_repository_factory.dart';
import 'package:for_server/persistence/ranking_repository.dart';
import 'package:test/test.dart';

class _FakeRankingRepository implements RankingRepository {
  @override
  Future<List<EntradaClasificacion>> cargarTop10() async {
    return const <EntradaClasificacion>[];
  }

  @override
  Future<List<EntradaClasificacion>> cargarRankingCompleto() async {
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
      () => crearRankingRepositoryDesdeDbSpec('   '),
      throwsA(isA<FormatException>()),
    );
  });

  test('usa sqlite cuando dbSpec no es URL de postgres', () async {
    final _FakeRankingRepository sqliteRepository = _FakeRankingRepository();

    final RankingBackend backend = await crearRankingRepositoryDesdeDbSpec(
      'bin/leaderboard.sqlite3',
      sqliteStoreOpener: (_) => sqliteRepository,
      postgresStoreOpener: (_) async =>
          throw StateError('no debe usar postgres'),
    );

    expect(backend.repository, same(sqliteRepository));
    expect(backend.descripcion.startsWith('SQLite '), isTrue);
  });

  test('usa postgres cuando dbSpec es URL postgres', () async {
    final _FakeRankingRepository postgresRepository = _FakeRankingRepository();

    final RankingBackend backend = await crearRankingRepositoryDesdeDbSpec(
      'postgres://user:pass@localhost:5432/for_db',
      sqliteStoreOpener: (_) => throw StateError('no debe usar sqlite'),
      postgresStoreOpener: (_) async => postgresRepository,
    );

    expect(backend.repository, same(postgresRepository));
    expect(backend.descripcion.startsWith('PostgreSQL '), isTrue);
    expect(backend.descripcion.contains('/for_db'), isTrue);
  });
}
