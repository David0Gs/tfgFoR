import 'package:flutter/material.dart';

import '../presentation/for_theme.dart';

/// Configuración compartida del visor 3D
/// Valores comunes a ambas plataformas (web y desktop vía Three.js)
class VisorConfig {
  static const String scenarioModelPath = 'assets/models/escenario.glb';

  // --- Cámara por defecto ---
  static const double cameraDefaultRoll = 20;
  static const double cameraDefaultPitch = 45;
  static const double cameraDefaultDistance = 35;

  // --- Límites de cámara ---
  static const double zoomMin = 20;
  static const double zoomMax = 50;
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
  static String get thumbnailBackgroundColorHex => thumbnailBackgroundColor.rgbHex;

  // --- Carga ---
  static const Color progressColor = ForColors.gold;
  static const Duration loadTimeout = Duration(seconds: 10);
}
