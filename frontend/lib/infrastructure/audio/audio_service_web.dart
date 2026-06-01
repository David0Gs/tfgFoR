// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

// Implementacion web del servicio de audio. Carga el MP3 como asset y usa un
// AudioElement oculto, respetando las restricciones de autoplay del navegador.

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_service_contract.dart';

/// Crea la implementacion de audio para navegador.
AudioServiceContract createAudioService() => _AudioServiceWeb();

/// Servicio de audio basado en un AudioElement HTML.
class _AudioServiceWeb implements AudioServiceContract {
  static const String _musicAssetKey = 'assets/music/Roman Empire Music.mp3';

  @override
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);

  html.AudioElement? _audioElement;
  bool _initialized = false;
  bool _initializing = false;
  bool _autoplayPendiente = false;
  bool _hayInteraccionUsuario = false;
  bool _reintentando = false;
  String? _objectUrl;

  /// Carga el asset de audio y prepara el AudioElement oculto.
  @override
  Future<void> initialize() async {
    if (_initialized || _initializing) {
      return;
    }

    _initializing = true;
    try {
      final ByteData audioAsset = await rootBundle.load(_musicAssetKey);
      final Uint8List bytes = audioAsset.buffer.asUint8List(
        audioAsset.offsetInBytes,
        audioAsset.lengthInBytes,
      );
      _objectUrl ??= html.Url.createObjectUrlFromBlob(
        html.Blob(<Object>[bytes], 'audio/mpeg'),
      );

      final html.AudioElement audioElement = html.AudioElement()
        ..src = _objectUrl!
        ..loop = true
        ..preload = 'auto'
        ..muted = isMuted.value;
      audioElement.load();
      _adjuntarAudioElementSiHaceFalta(audioElement);
      _audioElement = audioElement;
      _initialized = true;
      if (_hayInteraccionUsuario) {
        _intentarReproducirDesdeInteraccion();
      } else {
        await _intentarReproducir();
      }
    } catch (error, stackTrace) {
      debugPrint('AudioServiceWeb init error: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _initializing = false;
    }
  }

  /// Intenta iniciar la musica si la plataforma ya lo permite.
  @override
  Future<void> ensureStarted() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    await _intentarReproducir();
  }

  /// Alterna el silencio del AudioElement.
  @override
  Future<void> toggleMuted() async {
    final html.AudioElement? audioElement = _audioElement;
    if (isMuted.value) {
      isMuted.value = false;
      if (audioElement != null) {
        audioElement.muted = false;
      }
      await ensureStarted();
      return;
    }

    isMuted.value = true;
    _autoplayPendiente = false;
    if (audioElement == null) {
      return;
    }

    audioElement.muted = true;
    audioElement.pause();
  }

  /// Registra una pulsacion/toque para desbloquear autoplay en navegador.
  @override
  void registrarInteraccionUsuario() {
    _hayInteraccionUsuario = true;

    if (isMuted.value || _reintentando) {
      return;
    }
    if (!_initialized) {
      unawaited(initialize());
      return;
    }
    if (!_autoplayPendiente && !(_audioElement?.paused ?? true)) {
      return;
    }

    _reintentando = true;
    _intentarReproducirDesdeInteraccion();
  }

  /// Intenta reproducir la musica y marca si el navegador lo bloquea.
  Future<void> _intentarReproducir() async {
    final html.AudioElement? audioElement = _audioElement;
    if (!_initialized || isMuted.value || audioElement == null) {
      return;
    }
    if (!audioElement.paused) {
      _autoplayPendiente = false;
      return;
    }

    try {
      audioElement.muted = false;
      await audioElement.play();
      _autoplayPendiente = false;
    } catch (error, stackTrace) {
      _autoplayPendiente = true;
      debugPrint('AudioServiceWeb play blocked/error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Reintenta reproducir justo despues de una interaccion de usuario.
  void _intentarReproducirDesdeInteraccion() {
    final html.AudioElement? audioElement = _audioElement;
    if (!_initialized || isMuted.value || audioElement == null) {
      _reintentando = false;
      return;
    }
    if (!audioElement.paused) {
      _autoplayPendiente = false;
      _reintentando = false;
      return;
    }

    try {
      audioElement.muted = false;
      unawaited(
        audioElement
            .play()
            .then((_) {
              _autoplayPendiente = false;
            })
            .catchError((Object error, StackTrace stackTrace) {
              _autoplayPendiente = true;
              debugPrint('AudioServiceWeb play blocked/error: $error');
              debugPrintStack(stackTrace: stackTrace);
            })
            .whenComplete(() {
              _reintentando = false;
            }),
      );
    } catch (error, stackTrace) {
      _autoplayPendiente = true;
      _reintentando = false;
      debugPrint('AudioServiceWeb play blocked/error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Inserta el AudioElement oculto en el documento si aun no esta montado.
  void _adjuntarAudioElementSiHaceFalta(html.AudioElement audioElement) {
    if (audioElement.parent != null) {
      return;
    }

    audioElement.style.display = 'none';
    html.document.body?.append(audioElement);
  }
}
