// Export condicional de persistencia de partidas. En web descarga/sube JSON
// desde el navegador y en plataformas no web usa un archivo local.

export 'persistencia_partida_stub.dart'
    if (dart.library.html) 'persistencia_partida_web.dart';
