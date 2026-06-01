// Configuracion global que debe ejecutarse antes o alrededor de `runApp`.
// No decide que pantalla se muestra: prepara servicios de plataforma que
// afectan a toda la aplicacion, como plugins nativos, ventana de escritorio y
// desbloqueo de audio tras la primera interaccion.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'infrastructure/audio/audio_service.dart';
import 'presentation/for_theme.dart';

/// Agrupa la configuracion de plataforma que debe prepararse antes de pintar.
class ApplicationConfig {
  /// Tamaño minimo usado en pantallas de menu o dialogos principales.
  static const Size menuMinimumSize = Size(328, 480);

  /// Tamaño minimo del tablero, donde el visor 3D necesita mas espacio.
  static const Size boardMinimumSize = Size(860, 600);

  /// Indica si la app se esta ejecutando como aplicacion de escritorio.
  static bool get isDesktopPlatform =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Prepara Flutter y registra los plugins que dependen de la plataforma.
  ///
  /// Se llama una sola vez desde `runFlutterApp`, antes de construir la UI.
  static Future<void> inicializar() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Registra el backend de video usado por miniaturas y multimedia en
    // escritorio.
    fvp.registerWith(
      options: {
        'platforms': <String>['windows', 'linux', 'macos'],
      },
    );
    // En web se desactiva el menu contextual del navegador para que los clicks
    // sobre la escena 3D y la UI se comporten como en una aplicacion.
    if (kIsWeb) {
      await BrowserContextMenu.disableContextMenu();
    }
    // En Windows el WebView embebido necesita registrar explicitamente su
    // implementacion antes de crear widgets que lo usen.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      WindowsInAppWebViewPlatform.registerWith();
    }
    // En escritorio se configura la ventana nativa: tamano minimo, titulo,
    // centrado inicial y maximizado automatico en Windows.
    if (!kIsWeb && isDesktopPlatform) {
      await windowManager.ensureInitialized();
      const WindowOptions windowOptions = WindowOptions(
        center: true,
        minimumSize: menuMinimumSize,
        title: "Foundations of Rome - Juego de Mesa Virtual",
        backgroundColor: ForColors.transparent,
        skipTaskbar: false,
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        if (defaultTargetPlatform == TargetPlatform.windows) {
          await windowManager.maximize();
        }
        await windowManager.focus();
      });
    }
  }

  /// Envuelve toda la app para detectar la primera interaccion del usuario.
  ///
  /// Algunos navegadores bloquean audio automatico hasta que el usuario pulsa
  /// o toca la pantalla. Este Listener informa al servicio de audio de que ya
  /// hubo interaccion y puede intentar reproducir musica o sonidos.
  static Widget envolverInteraccionesGlobales({required Widget child}) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        AudioService.instance.registrarInteraccionUsuario();
      },
      child: child,
    );
  }
}
