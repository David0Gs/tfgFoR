// Inicializador especifico del visor web. Inyecta en WebViewerWidget la funcion
// que registra iframes y comunica Flutter con Three.js.

import 'visor_web_widget.dart';
import 'visor_web_controlador.dart';

/// Configura el visor web al arrancar en navegador.
void init() {
  WebViewerWidget.injectWebSetup(setupWebViewer);
}
