import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:fvp/fvp.dart' as fvp;

import 'infrastructure/audio/audio_service.dart';
import 'presentation/for_theme.dart';

/// Configuración e inicialización de la aplicación
/// Gestiona registro de plataformas y ventana de escritorio
class ApplicationConfig {
  static const Size menuMinimumSize = Size(328, 480);
  static const Size boardMinimumSize = Size(860, 600);

  static bool get _isDesktopPlatform =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Inicializa la plataforma según el entorno (web o desktop)
  static Future<void> inicializar() async {
    WidgetsFlutterBinding.ensureInitialized();
    fvp.registerWith(options: {
      'platforms': <String>['windows', 'linux', 'macos'],
    });

    if (kIsWeb) {
      await BrowserContextMenu.disableContextMenu();
    }

    // Registrar plataforma InAppWebView para Windows
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      WindowsInAppWebViewPlatform.registerWith();
    }

    // Configurar window manager solo en plataformas de escritorio.
    if (!kIsWeb && _isDesktopPlatform) {
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
