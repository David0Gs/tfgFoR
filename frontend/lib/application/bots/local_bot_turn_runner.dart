// Ejecutor de turnos automaticos en partidas locales. Mantiene al bot jugando
// hasta que vuelva el turno de una persona o termine la partida.

import 'package:for_core/core.dart';
import 'bot_planned_action.dart';
import 'foundations_of_rome_bot_service.dart';

/// Procesa turnos pendientes de jugadores bot dentro de una partida local.
class LocalBotTurnRunner {
  LocalBotTurnRunner({
    FoundationsOfRomeBotService? botService,
    this.stepDelay = const Duration(milliseconds: 450),
  }) : _botService = botService ?? FoundationsOfRomeBotService();

  final FoundationsOfRomeBotService _botService;
  final Duration stepDelay;
  bool _processing = false;

  /// Indica si ya se esta ejecutando una cadena de turnos de bots.
  bool get isProcessing => _processing;

  /// Ejecuta turnos de bots consecutivos mientras el jugador actual sea bot.
  Future<void> processPendingTurns({
    required Juego game,
    required bool localModeEnabled,
    required Future<void> Function() synchronizeState,
    required bool Function() isMounted,
    Future<void> Function(BotPlannedAction action)? executeAction,
  }) async {
    if (_processing || !localModeEnabled) {
      return;
    }

    _processing = true;
    try {
      while (localModeEnabled &&
          !game.partidaFinalizada &&
          game.players[game.indiceJugadorActual].isBot) {
        if (stepDelay > Duration.zero) {
          await Future<void>.delayed(stepDelay);
        }

        try {
          final BotPlannedAction action = _botService.decide(game);
          if (executeAction == null) {
            action.apply(game);
            await synchronizeState();
          } else {
            await executeAction(action);
          }
        } on RuleError {
          game.accionIngresos();
          await synchronizeState();
        }

        if (!isMounted()) {
          return;
        }
      }
    } finally {
      _processing = false;
    }
  }
}
