// Error de reglas del juego. Se lanza cuando una accion no es valida segun el
// estado actual de la partida.

import 'game_error.dart';

/// Excepcion para acciones que incumplen reglas de Foundations of Rome.
class RuleError extends GameError {
  const RuleError(super.message);
}
