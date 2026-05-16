import 'package:flutter_test/flutter_test.dart';
import 'package:prueba_tfg/domain/foundations_of_rome/foundations_of_rome.dart';
import 'package:prueba_tfg/presentation/screens/pantalla_tablero.dart';

void main() {
  group('Build validation', () {
    test('validateBuild throws when origin lot is not owned', () {
      final Juego game = Juego(2);
      final Jugador player = game.players[game.indiceJugadorActual];
      final Edificio domus = buscarEdificioPorId('DomusI')!;

      player.lots.add('A1');

      expect(
        () => game.validarConstruccion('B1', domus, 0, 0, false),
        throwsA(
          isA<RuleError>().having(
            (RuleError error) => error.message,
            'message',
            contains('pertenezca'),
          ),
        ),
      );
    });

    test('validateBuild throws when footprint includes a lot not owned', () {
      final Juego game = Juego(2);
      final Jugador player = game.players[game.indiceJugadorActual];
      final Edificio domusMaxima = buscarEdificioPorId('DomusMaximaI')!;
      final int buildingIdx = player.availableBuildings.indexWhere(
        (building) => building.id == domusMaxima.id,
      );

      player.lots.add('A1');

      expect(
        () => game.validarConstruccion('A1', domusMaxima, 0, buildingIdx, false),
        throwsA(
          isA<RuleError>().having(
            (RuleError error) => error.message,
            'message',
            contains('No posees derechos'),
          ),
        ),
      );
    });

    test('actionBuild rejects replacing with same-size building', () {
      final Juego game = Juego(2);
      final Jugador player = game.players[game.indiceJugadorActual];
      final Edificio domusI = buscarEdificioPorId('DomusI')!;
      final Edificio domusII = buscarEdificioPorId('DomusII')!;
      final int domusIIdx = player.availableBuildings.indexWhere(
        (building) => building.id == domusI.id,
      );

      player.lots.add('A1');
      game.propietariosLotes['A1'] = player.id;
      game.construir('A1', domusI, 0, domusIIdx, false);

      game.indiceJugadorActual = player.id;
      final int domusIIIdx = player.availableBuildings.indexWhere(
        (building) => building.id == domusII.id,
      );

      expect(
        () => game.construir('A1', domusII, 0, domusIIIdx, false),
        throwsA(
          isA<RuleError>().having(
            (RuleError error) => error.message,
            'message',
            contains('debe ocupar mas parcelas'),
          ),
        ),
      );
      expect(game.edificios['A1']?.template.id, domusI.id);
      expect(
        player.availableBuildings.any((building) => building.id == domusI.id),
        isFalse,
      );
      expect(
        player.availableBuildings.any((building) => building.id == domusII.id),
        isTrue,
      );
      expect(player.availableMarkers, 9);
    });

    test('actionBuild mutates state on a valid construction', () {
      final Juego game = Juego(2);
      final Jugador player = game.players[game.indiceJugadorActual];
      final Edificio domus = buscarEdificioPorId('DomusI')!;
      final int buildingIdx = player.availableBuildings.indexWhere(
        (building) => building.id == domus.id,
      );

      player.lots.add('A1');
      game.propietariosLotes['A1'] = player.id;

      final bool result = game.construir('A1', domus, 0, buildingIdx, false);

      expect(result, isTrue);
      expect(game.edificios['A1']?.template.id, domus.id);
      expect(player.availableMarkers, 9);
    });

    test('single-lot buildings accept visual rotation indexes', () {
      final Juego game = Juego(2);
      final Jugador player = game.players[game.indiceJugadorActual];
      final Edificio domus = buscarEdificioPorId('DomusI')!;
      final int buildingIdx = player.availableBuildings.indexWhere(
        (building) => building.id == domus.id,
      );

      player.lots.add('A1');
      game.propietariosLotes['A1'] = player.id;

      final bool result = game.construir('A1', domus, 3, buildingIdx, false);

      expect(result, isTrue);
      expect(game.edificios['A1']?.rotationIndex, 3);
      expect(game.edificios['A1']?.occupiedCoords, ['A1']);
    });

    test('building ids do not map to a placement origin', () {
      expect(coordFromObjectId('built_p1_DomusMaximaI_F6_F5'), isNull);
      expect(coordFromObjectId('built_p1_InsulaL_F5_F6_G6'), isNull);
      expect(coordFromObjectId('tile:F6'), 'F6');
    });

    test('extract occupied coords from built object ids', () {
      expect(
        occupiedCoordsFromBuiltObjectId('built_p1_DomusMaximaI_F6_F5'),
        ['F6', 'F5'],
      );
      expect(
        occupiedCoordsFromBuiltObjectId('built_p1_InsulaL_F5_F6_G6'),
        ['F5', 'F6', 'G6'],
      );
      expect(occupiedCoordsFromBuiltObjectId('tile:F6'), isEmpty);
    });
  });
}
