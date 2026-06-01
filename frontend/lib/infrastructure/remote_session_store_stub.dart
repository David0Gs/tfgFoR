// Almacenamiento local de identificador de cliente y tokens de sesion remota
// para plataformas no web. Guarda un JSON en una carpeta local escribible.

import 'dart:convert';
import 'dart:io';

/// Persistencia de sesiones remotas para escritorio y movil.
class RemoteSessionStore {
  /// Lee el identificador estable de este cliente.
  Future<String?> readClientId() async {
    final Map<String, dynamic> data = await _readData();
    return data['clientId'] as String?;
  }

  /// Guarda el identificador estable de este cliente.
  Future<void> writeClientId(String clientId) async {
    final Map<String, dynamic> data = await _readData();
    data['clientId'] = clientId;
    await _writeData(data);
  }

  /// Lee una sesion recordada por clave servidor/alias.
  Future<String?> readSession(String key) async {
    final Map<String, dynamic> data = await _readData();
    final Map<String, dynamic> sessions =
        (data['sessions'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    return sessions[key] as String?;
  }

  /// Guarda una sesion recordada por clave servidor/alias.
  Future<void> writeSession(String key, String value) async {
    final Map<String, dynamic> data = await _readData();
    final Map<String, dynamic> sessions =
        (data['sessions'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    sessions[key] = value;
    data['sessions'] = sessions;
    await _writeData(data);
  }

  /// Elimina una sesion recordada que ya no es valida.
  Future<void> deleteSession(String key) async {
    final Map<String, dynamic> data = await _readData();
    final Map<String, dynamic> sessions =
        (data['sessions'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    sessions.remove(key);
    data['sessions'] = sessions;
    await _writeData(data);
  }

  /// Lee todo el JSON de sesiones desde disco.
  Future<Map<String, dynamic>> _readData() async {
    final File file = await _storeFile();
    if (!await file.exists()) {
      return <String, dynamic>{};
    }
    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  /// Escribe todo el JSON de sesiones en disco.
  Future<void> _writeData(Map<String, dynamic> data) async {
    final File file = await _storeFile();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(data), flush: true);
  }

  /// Calcula el archivo donde se guardan las sesiones remotas.
  Future<File> _storeFile() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final Directory baseDir = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}Foundations of Rome',
      );
      return File(
        '${baseDir.path}${Platform.pathSeparator}remote_sessions.json',
      );
    }

    final String? home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final Directory baseDir = home == null || home.trim().isEmpty
        ? Directory.current
        : Directory(
            '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}Foundations of Rome',
          );
    return File('${baseDir.path}${Platform.pathSeparator}remote_sessions.json');
  }
}
