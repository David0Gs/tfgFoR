// ignore_for_file: library_prefixes

// Factoría multiplataforma del visor 3D. Decide si se debe usar la version web,
// escritorio o movil sin que la pantalla del tablero conozca esos detalles.

import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'interfaz_controlador.dart';
import 'plataformas/visor_desktop.dart';
import 'plataformas/visor_mobile.dart';
import 'plataformas/web/visor_web_widget.dart';
import 'plataformas/web/inicializador_stub.dart'
    if (dart.library.html) 'plataformas/web/inicializador_web.dart'
    as webInit;

/// Crea el visor 3D apropiado segun la plataforma actual.
class Visor3DFactory {
  static final Visor3DFactory _instance = Visor3DFactory._internal();

  factory Visor3DFactory() => _instance;
  Visor3DFactory._internal() {
    webInit.init();
  }

  /// Crea un widget visor 3D optimizado para la plataforma actual.
  Widget createViewerWidget({
    required String modelPath,
    required Completer<I3DViewerController> controllerCompleter,
    bool interactive = true,
    bool loadScenario = true,
    String? backgroundColorHex,
    bool renderContinuously = false,
    bool isThumbnail = false,
  }) {
    if (kIsWeb) {
      return WebViewerWidget(
        modelPath: modelPath,
        controllerCompleter: controllerCompleter,
        interactive: interactive,
        loadScenario: loadScenario,
        backgroundColorHex: backgroundColorHex,
        renderContinuously: renderContinuously,
        isThumbnail: isThumbnail,
      );
    }

    if (_isDesktopPlatform) {
      return DesktopViewerWidget(
        modelPath: modelPath,
        controllerCompleter: controllerCompleter,
        interactive: interactive,
        loadScenario: loadScenario,
        backgroundColorHex: backgroundColorHex,
        renderContinuously: renderContinuously,
        isThumbnail: isThumbnail,
      );
    }

    return MobileViewerWidget(
      modelPath: modelPath,
      controllerCompleter: controllerCompleter,
      interactive: interactive,
      loadScenario: loadScenario,
      backgroundColorHex: backgroundColorHex,
      renderContinuously: renderContinuously,
      isThumbnail: isThumbnail,
    );
  }

  bool get _isDesktopPlatform =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Obtiene el nombre del motor 3D actualmente en uso.
  String get currentEngine => "Three.js";

  /// Indica si la plataforma actual es web.
  bool get isWeb => kIsWeb;
}
