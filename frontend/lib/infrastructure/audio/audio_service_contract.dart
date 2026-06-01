// Contrato comun del servicio de audio. Las implementaciones web y nativa
// cumplen esta interfaz para que la UI no dependa de detalles de plataforma.

import 'package:flutter/foundation.dart';

/// Operaciones de audio que necesita la aplicacion.
abstract class AudioServiceContract {
  /// Estado observable usado por la UI para pintar el boton de silencio.
  ValueNotifier<bool> get isMuted;

  /// Prepara recursos de audio de la plataforma.
  Future<void> initialize();

  /// Garantiza que la musica este arrancada si no esta silenciada.
  Future<void> ensureStarted();

  /// Alterna entre silenciado y sonido activo.
  Future<void> toggleMuted();

  /// Notifica que el usuario ya interactuo con la app.
  void registrarInteraccionUsuario();
}
