import 'visor_web_widget.dart';
import 'visor_web_controlador.dart';

/// Inicializador específico para web
/// Este módulo solo se importa en contexto web para evitar errores de compilación
void init() {
  WebViewerWidget.injectWebSetup(setupWebViewer);
}
