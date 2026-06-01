// Error base del motor de juego. Permite agrupar errores de reglas y otros
// fallos propios del dominio bajo una excepcion comun.

/// Excepcion base para errores del motor.
abstract class GameError implements Exception {
  const GameError(this.message);

  final String message;

  @override
  String toString() => message;
}
