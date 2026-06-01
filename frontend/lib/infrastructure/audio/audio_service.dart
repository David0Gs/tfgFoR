// Fachada unica del servicio de audio. Elige automaticamente la implementacion
// nativa o web mediante imports condicionales.

import 'audio_service_contract.dart';
import 'audio_service_native.dart'
    if (dart.library.html) 'audio_service_web.dart'
    as backend;

/// Acceso global al servicio de audio de la plataforma actual.
class AudioService {
  AudioService._();

  static final AudioServiceContract instance = backend.createAudioService();
}
