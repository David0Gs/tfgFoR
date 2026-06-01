// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

// Almacenamiento de identificador de cliente y tokens de sesion remota en web.
// Usa localStorage para sobrevivir a recargas del navegador.

import 'dart:html' as html;

/// Persistencia de sesiones remotas para navegador.
class RemoteSessionStore {
  static const String _clientIdKey = 'for_remote_client_id';
  static const String _sessionPrefix = 'for_remote_session_';

  /// Lee el identificador estable de este navegador.
  Future<String?> readClientId() async {
    return html.window.localStorage[_clientIdKey];
  }

  /// Guarda el identificador estable de este navegador.
  Future<void> writeClientId(String clientId) async {
    html.window.localStorage[_clientIdKey] = clientId;
  }

  /// Lee una sesion recordada por clave servidor/alias.
  Future<String?> readSession(String key) async {
    return html.window.localStorage['$_sessionPrefix$key'];
  }

  /// Guarda una sesion recordada por clave servidor/alias.
  Future<void> writeSession(String key, String value) async {
    html.window.localStorage['$_sessionPrefix$key'] = value;
  }

  /// Elimina una sesion recordada que ya no es valida.
  Future<void> deleteSession(String key) async {
    html.window.localStorage.remove('$_sessionPrefix$key');
  }
}
