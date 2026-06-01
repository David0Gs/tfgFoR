// Cargador simple de archivos .env para el servidor. Permite configurar el
// backend sin pasar todos los parametros por linea de comandos.

import 'dart:io';

/// Lee variables desde `.env` o `backend/.env` si existe.
Future<Map<String, String>> loadServerEnvFile({File? envFile}) async {
  final File? file = envFile ?? _findDefaultEnvFile();
  if (file == null || !await file.exists()) {
    return const <String, String>{};
  }

  final Map<String, String> values = <String, String>{};
  final List<String> lines = await file.readAsLines();
  for (final String rawLine in lines) {
    final String line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    final String normalizedLine = line.startsWith('export ')
        ? line.substring('export '.length).trim()
        : line;
    final int separatorIndex = normalizedLine.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }

    final String key = normalizedLine.substring(0, separatorIndex).trim();
    final String value = _cleanValue(
      normalizedLine.substring(separatorIndex + 1).trim(),
    );
    if (key.isNotEmpty) {
      values[key] = value;
    }
  }

  return values;
}

/// Busca el archivo .env por defecto segun desde donde se arranque el server.
File? _findDefaultEnvFile() {
  final List<File> candidates = <File>[File('.env'), File('backend/.env')];

  for (final File candidate in candidates) {
    if (candidate.existsSync()) {
      return candidate;
    }
  }

  return null;
}

/// Limpia comillas simples o dobles alrededor de un valor.
String _cleanValue(String value) {
  if (value.length < 2) {
    return value;
  }

  final String first = value[0];
  final String last = value[value.length - 1];
  if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
    return value.substring(1, value.length - 1);
  }

  return value;
}
