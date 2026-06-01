// Export condicional del almacenamiento de sesiones remotas. En web usa
// localStorage y en escritorio/movil usa un archivo JSON local.

export 'remote_session_store_stub.dart'
    if (dart.library.html) 'remote_session_store_web.dart';
