// Constantes compartidas por el visor 3D: camara, limites de zoom, colores y
// tiempos de carga. Las usan tanto web como escritorio/movil.

import 'package:flutter/material.dart';

import '../presentation/for_theme.dart';

/// Configuracion compartida del visor 3D.
class VisorConfig {
  static const String scenarioModelPath = 'assets/models/escenario.glb';

  // --- Cámara por defecto ---
  static const double cameraDefaultRoll = 20;
  static const double cameraDefaultPitch = 45;
  static const double cameraDefaultDistance = 35;

  // --- Límites de cámara ---
  static const double zoomMin = 10;
  static const double zoomMax = 60;
  static const double polarAngleMin = 0; // grados desde la vertical
  static const double polarAngleMax = 80; // grados desde la vertical

  // --- Target de cámara por defecto ---
  static const double cameraTargetX = 0;
  static const double cameraTargetY = 0;
  static const double cameraTargetZ = 0;

  // --- Escena ---
  static const Color backgroundColor = ForColors.sceneBackground;
  static String get backgroundColorHex => backgroundColor.rgbHex;
  static const Color thumbnailBackgroundColor = ForColors.thumbnailBackground;
  static String get thumbnailBackgroundColorHex =>
      thumbnailBackgroundColor.rgbHex;

  // --- Carga ---
  static const Color progressColor = ForColors.gold;
  static const Duration loadTimeout = Duration(seconds: 10);
}
