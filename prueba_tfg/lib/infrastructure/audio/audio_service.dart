import 'audio_service_contract.dart';
import 'audio_service_native.dart'
    if (dart.library.html) 'audio_service_web.dart'
    as backend;

class AudioService {
  AudioService._();

  static final AudioServiceContract instance = backend.createAudioService();
}
