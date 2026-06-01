// Configuracion de arranque del servidor. Fusiona argumentos CLI y variables
// de entorno, valida valores obligatorios y deja todo en un objeto tipado.

/// Parametros efectivos con los que se arranca el backend.
class ServerConfig {
  const ServerConfig({
    required this.host,
    required this.port,
    required this.playerCount,
    required this.dbSpec,
    required this.sqliteFallbackSpec,
    required this.accessToken,
    required this.restoreRooms,
  });

  final String host;
  final int port;
  final int playerCount;
  final String dbSpec;
  final String sqliteFallbackSpec;
  final String accessToken;
  final bool restoreRooms;

  static const String envHost = 'FOR_HOST';
  static const String envPort = 'FOR_PORT';
  static const String envPlayers = 'FOR_PLAYERS';
  static const String envDb = 'FOR_DB';
  static const String envSqliteFallback = 'FOR_SQLITE_FALLBACK';
  static const String envAccessToken = 'FOR_ACCESS_TOKEN';
  static const String envRestoreRooms = 'FOR_RESTORE_ROOMS';

  /// Construye configuracion combinando argumentos y entorno.
  factory ServerConfig.fromArgsAndEnv(
    List<String> args, {
    Map<String, String> environment = const <String, String>{},
  }) {
    final Map<String, String> opciones = parseArgs(args);
    final String host =
        _valor(opciones, environment, 'host', envHost) ?? '0.0.0.0';
    final int port = _parseInt(
      _valor(opciones, environment, 'port', envPort),
      fallback: 8080,
    );
    final int playerCount = _parseInt(
      _valor(opciones, environment, 'players', envPlayers),
      fallback: 2,
    );

    return ServerConfig(
      host: host,
      port: port,
      playerCount: playerCount,
      dbSpec: (_valor(opciones, environment, 'db', envDb) ?? '').trim(),
      sqliteFallbackSpec:
          (_valor(
                    opciones,
                    environment,
                    'sqlite-fallback',
                    envSqliteFallback,
                  ) ??
                  '')
              .trim(),
      accessToken:
          (_valor(opciones, environment, 'access-token', envAccessToken) ?? '')
              .trim(),
      restoreRooms: _parseBool(
        _valor(opciones, environment, 'restore-rooms', envRestoreRooms),
        fallback: false,
      ),
    );
  }

  /// Valida que la configuracion minima sea usable.
  void validar() {
    if (playerCount < 2 || playerCount > 5) {
      throw const FormatException(
        'El numero de jugadores debe estar entre 2 y 5.',
      );
    }
    if (dbSpec.isEmpty) {
      throw const FormatException('Falta el parametro obligatorio --db.');
    }
  }

  /// Parsea argumentos tipo `--db=...`, `--db ...` o `db=...`.
  static Map<String, String> parseArgs(List<String> args) {
    final Map<String, String> opciones = <String, String>{};
    for (int index = 0; index < args.length; index++) {
      final String arg = args[index];

      if (arg.startsWith('--') && arg.contains('=')) {
        final int separatorIndex = arg.indexOf('=');
        final String key = arg.substring(2, separatorIndex);
        final String value = arg.substring(separatorIndex + 1);
        if (key.isNotEmpty) {
          opciones[key] = value;
        }
        continue;
      }

      if (arg.startsWith('--') && index + 1 < args.length) {
        final String key = arg.substring(2);
        final String nextArg = args[index + 1];
        if (key.isEmpty || nextArg.startsWith('-') || nextArg.contains('=')) {
          continue;
        }
        opciones[key] = nextArg;
        index++;
        continue;
      }

      if (arg.contains('=')) {
        final int separatorIndex = arg.indexOf('=');
        final String key = arg.substring(0, separatorIndex);
        final String value = arg.substring(separatorIndex + 1);
        if (key.isNotEmpty) {
          opciones[key] = value;
        }
      }
    }
    return opciones;
  }

  /// Resuelve un valor dando prioridad al argumento CLI sobre el entorno.
  static String? _valor(
    Map<String, String> opciones,
    Map<String, String> environment,
    String argKey,
    String envKey,
  ) {
    final String? argValue = opciones[argKey];
    if (argValue != null && argValue.trim().isNotEmpty) {
      return argValue.trim();
    }

    final String? envValue = environment[envKey];
    if (envValue != null && envValue.trim().isNotEmpty) {
      return envValue.trim();
    }

    return null;
  }

  /// Convierte enteros tolerando valores ausentes o invalidos.
  static int _parseInt(String? rawValue, {required int fallback}) {
    if (rawValue == null) {
      return fallback;
    }
    return int.tryParse(rawValue) ?? fallback;
  }

  /// Convierte booleanos habituales de CLI/env a bool.
  static bool _parseBool(String? rawValue, {required bool fallback}) {
    if (rawValue == null) {
      return fallback;
    }
    final String normalized = rawValue.trim().toLowerCase();
    return switch (normalized) {
      '1' || 'true' || 'yes' || 'y' || 'on' => true,
      '0' || 'false' || 'no' || 'n' || 'off' => false,
      _ => fallback,
    };
  }
}
