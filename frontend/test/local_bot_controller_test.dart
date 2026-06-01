import 'package:flutter_test/flutter_test.dart';
import 'package:for_core/core.dart';
import 'package:frontend/application/bots/local_bots.dart';

void main() {
  group('Local bot controller', () {
    test(
      'advances a local game automatically when a bot turn starts',
      () async {
        final Juego game = Juego(
          2,
          playerKinds: const <TipoJugador>[TipoJugador.human, TipoJugador.bot],
        );
        final LocalBotTurnRunner runner = LocalBotTurnRunner(
          stepDelay: Duration.zero,
        );

        game.indiceJugadorActual = 1;
        int syncCalls = 0;

        await runner.processPendingTurns(
          game: game,
          localModeEnabled: true,
          synchronizeState: () async {
            syncCalls++;
          },
          isMounted: () => true,
        );

        expect(syncCalls, greaterThanOrEqualTo(1));
        expect(game.indiceJugadorActual, 0);
      },
    );

    test('chooses income when it cannot build or buy', () {
      final Juego game = Juego(
        2,
        playerKinds: const <TipoJugador>[TipoJugador.human, TipoJugador.bot],
      );
      final FoundationsOfRomeBotService service = FoundationsOfRomeBotService();

      game.indiceJugadorActual = 1;
      final Jugador bot = game.players[1];
      bot.coins = 1;
      bot.lots.clear();

      final BotPlannedAction action = service.decide(game);
      action.apply(game);

      expect(action.type, BotActionType.income);
      expect(bot.coins, greaterThanOrEqualTo(6));
      expect(game.indiceJugadorActual, 0);
    });

    test('chooses income instead of buying when it has no markers', () {
      final Juego game = Juego(
        2,
        playerKinds: const <TipoJugador>[TipoJugador.human, TipoJugador.bot],
      );
      final FoundationsOfRomeBotService service = FoundationsOfRomeBotService();

      game.indiceJugadorActual = 1;
      final Jugador bot = game.players[1];
      bot.coins = 10;
      bot.availableMarkers = 0;
      bot.lots.clear();

      final BotPlannedAction action = service.decide(game);
      action.apply(game);

      expect(action.type, BotActionType.income);
      expect(bot.coins, greaterThanOrEqualTo(15));
      expect(game.indiceJugadorActual, 0);
    });

    test(
      'falls back to income when a bot action raises a rule error',
      () async {
        final Juego game = Juego(
          2,
          playerKinds: const <TipoJugador>[TipoJugador.human, TipoJugador.bot],
        );
        final LocalBotTurnRunner runner = LocalBotTurnRunner(
          stepDelay: Duration.zero,
        );

        game.indiceJugadorActual = 1;
        final Jugador bot = game.players[1];
        final int initialCoins = bot.coins;
        int syncCalls = 0;

        await runner.processPendingTurns(
          game: game,
          localModeEnabled: true,
          synchronizeState: () async {
            syncCalls++;
          },
          isMounted: () => true,
          executeAction: (_) async {
            throw const RuleError('forced bot failure');
          },
        );

        expect(syncCalls, 1);
        expect(bot.coins, initialCoins + 5);
        expect(game.indiceJugadorActual, 0);
      },
    );

    test('chooses a larger replacement build when overwrite is valid', () {
      final Juego game = Juego(
        2,
        playerKinds: const <TipoJugador>[TipoJugador.human, TipoJugador.bot],
      );
      final FoundationsOfRomeBotService service = FoundationsOfRomeBotService();

      game.indiceJugadorActual = 1;
      final Jugador bot = game.players[1];
      bot.lots
        ..clear()
        ..addAll(const <String>{'A1', 'B1'});
      game.propietariosLotes['A1'] = bot.id;
      game.propietariosLotes['B1'] = bot.id;

      final Edificio domus = buscarEdificioPorId('DomusI')!;
      final Edificio domusMaxima = buscarEdificioPorId('DomusMaximaI')!;
      final int domusIdx = bot.availableBuildings.indexWhere(
        (Edificio building) => building.id == domus.id,
      );

      final bool initialBuild = game.construir('A1', domus, 0, domusIdx, false);
      expect(initialBuild, isTrue);

      game.indiceJugadorActual = bot.id;

      final BotPlannedAction action = service.decide(game);
      action.apply(game);

      expect(action.type, BotActionType.build);
      expect(action.building?.id, domusMaxima.id);
      expect(action.originCoord, 'A1');
      expect(game.edificios['A1']?.template.id, domusMaxima.id);
      expect(game.edificios['B1']?.template.id, domusMaxima.id);
      expect(
        bot.availableBuildings.any(
          (Edificio building) => building.id == domus.id,
        ),
        isTrue,
      );
      expect(game.indiceJugadorActual, 0);
    });
  });
}
