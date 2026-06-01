// Implementacion nativa del servicio de audio para escritorio y movil. Usa el
// paquete audioplayers para reproducir la musica en bucle.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_service_contract.dart';

/// Crea la implementacion de audio para plataformas no web.
AudioServiceContract createAudioService() => _AudioServiceNative();

/// Servicio de audio basado en audioplayers.
class _AudioServiceNative implements AudioServiceContract {
  static const String _musicAsset = 'music/Roman Empire Music.mp3';

  final AudioPlayer _player = AudioPlayer();

  @override
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);

  bool _initialized = false;
  bool _initializing = false;
  bool _starting = false;
  bool _haIniciadoReproduccion = false;
  bool _estaReproduciendo = false;

  /// Prepara el reproductor nativo y el modo de bucle.
  @override
  Future<void> initialize() async {
    if (_initialized || _initializing) {
      return;
    }

    _initializing = true;
    try {
      await _ejecutarProtegido(() async {
        await _player.setReleaseMode(ReleaseMode.loop);
      });
      _initialized = true;
      await ensureStarted();
    } finally {
      _initializing = false;
    }
  }

  /// Arranca o reanuda la musica si la app no esta silenciada.
  @override
  Future<void> ensureStarted() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    if (isMuted.value || _estaReproduciendo || _starting) {
      return;
    }

    _starting = true;
    try {
      await _ejecutarProtegido(() async {
        if (_haIniciadoReproduccion) {
          await _player.resume();
        } else {
          await _player.play(AssetSource(_musicAsset));
          _haIniciadoReproduccion = true;
        }
        _estaReproduciendo = true;
      });
    } finally {
      _starting = false;
    }
  }

  /// Alterna el silencio del reproductor.
  @override
  Future<void> toggleMuted() async {
    if (isMuted.value) {
      isMuted.value = false;
      await ensureStarted();
      return;
    }

    isMuted.value = true;
    await _ejecutarProtegido(() async {
      await _player.pause();
      _estaReproduciendo = false;
    });
  }

  /// En nativo no hace falta desbloquear audio tras una interaccion.
  @override
  void registrarInteraccionUsuario() {}

  /// Ejecuta acciones de audio sin propagar errores a la interfaz.
  Future<void> _ejecutarProtegido(Future<void> Function() accion) async {
    try {
      await accion();
    } catch (error, stackTrace) {
      debugPrint('AudioServiceNative error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
