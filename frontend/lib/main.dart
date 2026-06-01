// Punto de entrada estandar de Flutter. Mantiene el arranque minimo y delega
// la configuracion real de la aplicacion en app_entrypoint.dart.

import 'app_entrypoint.dart';

/// Ejecuta el arranque comun de la aplicacion Flutter.
Future<void> main() async {
  await runFlutterApp();
}
