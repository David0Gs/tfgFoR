// Logger minimo del servidor. Centraliza formato, nivel y timestamp para que
// los mensajes del backend sean consistentes.

/// Niveles de log soportados por el backend.
enum LogLevel { info, warning, error }

/// Logger simple basado en stdout.
class ServerLogger {
  const ServerLogger();

  /// Escribe un mensaje informativo.
  void info(String message) => _write(LogLevel.info, message);

  /// Escribe un aviso recuperable.
  void warning(String message) => _write(LogLevel.warning, message);

  /// Escribe un error, opcionalmente con excepcion asociada.
  void error(String message, [Object? error]) {
    final String suffix = error == null ? '' : ' | $error';
    _write(LogLevel.error, '$message$suffix');
  }

  /// Formatea y emite una linea de log.
  void _write(LogLevel level, String message) {
    final String timestamp = DateTime.now().toIso8601String();
    final String label = switch (level) {
      LogLevel.info => 'INFO',
      LogLevel.warning => 'WARN',
      LogLevel.error => 'ERROR',
    };
    // ignore: avoid_print
    print('[$timestamp] [$label] $message');
  }
}
