class GameError implements Exception {
  const GameError(this.message);

  final String message;

  @override
  String toString() => message;
}
