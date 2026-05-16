import 'package:flutter_test/flutter_test.dart';
import 'package:prueba_tfg/domain/entrada_leaderboard.dart';
import 'package:prueba_tfg/domain/alias_online.dart';
import '../bin/headless/ranking_global_sqlite.dart';

void main() {
  group('Alias online', () {
    test('rechaza alias invalido', () {
      expect(
        AliasOnline.mensajeError('AB'),
        'El alias online debe tener exactamente 3 caracteres.',
      );
      expect(
        AliasOnline.mensajeError('A*1'),
        'El alias online solo admite letras y numeros.',
      );
    });

    test('rechaza alias duplicado en la sesion', () {
      expect(
        AliasOnline.mensajeError(
          'abc',
          aliasesOcupados: const <String>['XYZ', 'AbC'],
        ),
        'El alias ABC ya esta ocupado en esta partida.',
      );
    });
  });

  group('Ranking global sqlite', () {
    late RankingGlobalSqlite ranking;

    setUp(() {
      ranking = RankingGlobalSqlite.enMemoria();
    });

    tearDown(() async {
      await ranking.close();
    });

    test('registra record cuando la nueva puntuacion es mayor', () async {
      await ranking.registrarPuntuacionMaxima(alias: 'abc', puntuacion: 12);

      final bool actualizado = await ranking.registrarPuntuacionMaxima(
        alias: 'ABC',
        puntuacion: 19,
      );

      expect(actualizado, isTrue);
      final List<EntradaClasificacion> top = await ranking.cargarTop10();
      expect(top, hasLength(1));
      expect(top.single.alias, 'ABC');
      expect(top.single.puntuacion, 19);
    });

    test('una puntuacion menor no sobrescribe el record', () async {
      await ranking.registrarPuntuacionMaxima(alias: 'ROM', puntuacion: 22);

      final bool actualizado = await ranking.registrarPuntuacionMaxima(
        alias: 'ROM',
        puntuacion: 17,
      );

      expect(actualizado, isFalse);
      final List<EntradaClasificacion> top = await ranking.cargarTop10();
      expect(top.single.alias, 'ROM');
      expect(top.single.puntuacion, 22);
    });

    test('carga el top 10 desde sqlite ordenado por puntuacion', () async {
      for (int index = 0; index < 12; index++) {
        await ranking.registrarPuntuacionMaxima(
          alias: 'A${index.toString().padLeft(2, '0')}',
          puntuacion: index,
        );
      }

      final List<EntradaClasificacion> top10 = await ranking.cargarTop10();

      expect(top10, hasLength(10));
      expect(top10.first.alias, 'A11');
      expect(top10.first.puntuacion, 11);
      expect(top10.last.alias, 'A02');
      expect(top10.last.puntuacion, 2);
    });
  });
}
