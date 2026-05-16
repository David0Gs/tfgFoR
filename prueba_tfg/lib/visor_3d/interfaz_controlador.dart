/// Interfaz base para controladores de visores 3D
/// Define las operaciones que cualquier visor 3D debe soportar
abstract class I3DViewerController {
  /// Callback cuando un modelo carga exitosamente (recibe el id del modelo)
  void Function(String modelId)? onModelLoaded;

  /// Callback cuando ocurre un error
  void Function(String error)? onError;

  /// Callback cuando el usuario hace click sobre un objeto interactivo de la escena
  void Function(String objectId)? onObjectClicked;

  // --- Cámara ---

  /// Configura la órbita de la cámara
  Future<void> setCameraOrbit(double roll, double pitch, double distance);

  /// Configura el punto focal de la cámara
  Future<void> setCameraTarget(double x, double y, double z);

  /// Resetea cámara a valores por defecto
  Future<void> resetCamera();

  // --- Gestión de modelos ---

  /// Carga un modelo GLB en la escena con un id y posición
  Future<void> loadModel(
    String id,
    String url, {
    double x = 0,
    double y = 0,
    double z = 0,
  });

  /// Elimina un modelo de la escena
  Future<void> removeModel(String id);

  /// Cambia la posición de un modelo
  Future<void> setModelPosition(String id, double x, double y, double z);

  /// Anima un modelo hasta la posición de una casilla del tablero.
  Future<void> animateModelToTile(
    String id,
    String coord, {
    double yOffset = 0,
    int durationMs = 220,
  });

  /// Cambia la rotación de un modelo (radianes)
  Future<void> setModelRotation(String id, double rx, double ry, double rz);

  /// Cambia la escala de un modelo
  Future<void> setModelScale(String id, double sx, double sy, double sz);

  /// Muestra u oculta un modelo
  Future<void> setModelVisible(String id, bool visible);

  /// Crea un marcador cúbico de color en la escena
  Future<void> createMarkerCube(
    String id, {
    required double x,
    required double y,
    required double z,
    required double size,
    required String colorHex,
  });

  /// Crea un marcador cúbico de color sobre la casilla del tablero indicada.
  /// La coordenada se resuelve en Three.js como A1 -> 0_0, B3 -> 1_2, etc.
  Future<void> createMarkerCubeOnTile(
    String id,
    String coord, {
    required double yOffset,
    required double size,
    required String colorHex,
  });

  /// Carga un modelo GLB y lo ancla a la casilla del tablero indicada
  Future<void> loadModelOnTile(
    String id,
    String url,
    String coord, {
    double yOffset = 0,
  });

  /// Marca o desmarca un objeto como clicable por el usuario
  Future<void> setObjectClickable(String id, bool clickable);

  /// Aplica estilo visual a un edificio cargado (contorno y color superior).
  Future<void> applyBuildingStyle(
    String id, {
    required String outlineHex,
    required String roofHex,
  });

  // --- Animaciones ---

  /// Reproduce una animación de un modelo
  Future<void> playAnimation(String modelId, String animationName);

  /// Pausa las animaciones de un modelo
  Future<void> pauseAnimation(String modelId);

  /// Obtiene la lista de animaciones de un modelo
  Future<List<String>> getAvailableAnimations(String modelId);

  /// Libera los recursos
  Future<void> dispose();
}
