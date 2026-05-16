import 'package:flutter/foundation.dart';

abstract class AudioServiceContract {
  ValueNotifier<bool> get isMuted;

  Future<void> initialize();

  Future<void> ensureStarted();

  Future<void> toggleMuted();

  void registrarInteraccionUsuario();
}
