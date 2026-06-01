// Controlador de la escena 3D del tablero. Traduce el estado del motor de
// juego a operaciones visuales: cargar modelos, mover previews, marcar solares
// comprados y mantener sincronizada la camara.

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:for_core/core.dart';
import 'visor_3d/interfaz_controlador.dart';
import 'visor_3d/camara_config.dart';
import 'presentation/for_theme.dart';

/// Coordina la interaccion entre la vista 3D y la logica del juego.
class TableroController {
  // Configuracion visual de la escena.
  final int colorFondo = 0xFF000000;
  final double luzIntensidad = 1.2;

  // Referencias al visor 3D y al callback de clicks sobre modelos.
  I3DViewerController? _visor3DController;
  void Function(String objectId)? _onObjectClicked;

  // Estado interno usado para evitar recargar modelos si no han cambiado.
  bool _visorListo = false;
  final Set<String> _markerIds = <String>{};
  final Set<String> _builtBuildingIds = <String>{};
  final Map<String, String> _buildingIdByOccupiedCoord = <String, String>{};
  final Set<String> _hiddenPreviewBuildingIds = <String>{};
  final Set<String> _hiddenPreviewMarkerIds = <String>{};
  final Map<String, int> _buildingRotationById = <String, int>{};
  final Map<String, String> _buildingStyleById = <String, String>{};
  final Map<String, bool> _modelVisibleById = <String, bool>{};
  final Map<String, bool> _modelClickableById = <String, bool>{};

  static const String _markerModelPath = 'assets/models/marcador.glb';
  static const double _markerY = 0.02;
  static const String previewEdificioId = 'preview_edificio';
  static const double _previewY = 0.42;
  static const double _buildingY = -0.07;
  static const int _buildingDropDurationMs = 520;

  TableroController();

  /// Asigna el controlador del visor 3D.
  void setVisor3DController(I3DViewerController controller) {
    _visor3DController = controller;
    _visor3DController?.onObjectClicked = _onObjectClicked;
    _visorListo = true;
    _resetSceneTracking();
    debugPrint("✅ Visor 3D controlador establecido");
  }

  /// Resetea la vista de la camara.
  Future<void> resetearVista() async {
    if (!_visorListo) return;

    debugPrint("🔄 Reseteando vista de cámara...");
    try {
      await _visor3DController?.resetCamera();
      debugPrint("✅ Vista reseteada");
    } catch (e) {
      debugPrint("❌ Error reseteando vista: $e");
    }
  }

  /// Centra el punto de orbita de la camara sobre una casilla concreta.
  Future<void> centrarCamaraEnCasilla(String coord) async {
    if (!_visorListo) return;

    try {
      await _visor3DController?.setCameraTargetToTile(coord);
    } catch (e) {
      debugPrint("Error centrando camara en $coord: $e");
    }
  }

  /// Configura la posicion de la camara.
  Future<void> configurarCamara({
    double roll = VisorConfig.cameraDefaultRoll,
    double pitch = VisorConfig.cameraDefaultPitch,
    double distance = VisorConfig.cameraDefaultDistance,
  }) async {
    if (!_visorListo) return;

    try {
      await _visor3DController?.setCameraOrbit(roll, pitch, distance);
      await _visor3DController?.setCameraTarget(
        VisorConfig.cameraTargetX,
        VisorConfig.cameraTargetY,
        VisorConfig.cameraTargetZ,
      );
    } catch (e) {
      debugPrint("❌ Error configurando cámara: $e");
    }
  }

  /// Obtiene el motor 3D en uso.
  String get motorActual => kIsWeb ? "Three.js (Web)" : "Three.js (Desktop)";

  /// Indica si el visor 3D ya esta listo para recibir operaciones.
  bool get visorListo => _visorListo;

  /// Registra el callback para clicks en objetos del entorno 3D.
  void registrarClickObjeto(void Function(String objectId)? onObjectClicked) {
    _onObjectClicked = onObjectClicked;
    _visor3DController?.onObjectClicked = onObjectClicked;
  }

  /// Sincroniza cubos marcadores para todos los lotes comprados.
  Future<void> sincronizarMarcadoresLotes(Juego game) async {
    if (!_visorListo || _visor3DController == null) return;

    final Stopwatch stopwatch = Stopwatch()..start();
    int cargados = 0;
    int eliminados = 0;

    final Set<String> desiredMarkerIds = <String>{};
    final Map<String, ({String coord, int playerId})> desiredMarkers =
        <String, ({String coord, int playerId})>{};

    for (final Jugador player in game.players) {
      for (final String coord in player.lots) {
        if (!game.isCoordOnBoard(coord) || game.edificios.containsKey(coord)) {
          continue;
        }

        final String markerId = 'lot_marker_p${player.id}_$coord';
        desiredMarkerIds.add(markerId);
        desiredMarkers[markerId] = (coord: coord, playerId: player.id);
      }
    }

    final Set<String> staleMarkerIds = _markerIds
        .difference(desiredMarkerIds)
        .toSet();
    for (final String markerId in staleMarkerIds) {
      await _visor3DController!.removeModel(markerId);
      _markerIds.remove(markerId);
      _hiddenPreviewMarkerIds.remove(markerId);
      _olvidarModelo(markerId);
      eliminados++;
    }

    for (final MapEntry<String, ({String coord, int playerId})> entry
        in desiredMarkers.entries) {
      final String markerId = entry.key;
      if (!_markerIds.contains(markerId)) {
        await _cargarModeloYEsperarListo(
          markerId,
          () => _visor3DController!.loadModelOnTile(
            markerId,
            _markerModelPath,
            entry.value.coord,
            yOffset: _markerY,
          ),
        );
        _markerIds.add(markerId);
        cargados++;
      }

      await _setModelVisibleIfChanged(markerId, true);
      await _setObjectClickableIfChanged(markerId, true);
      await _applyBuildingStyleIfChanged(
        markerId,
        outlineHex: _hexColorJugador(entry.value.playerId),
        roofHex: _hexColorJugador(entry.value.playerId),
      );
    }

    _logPerf(
      'sync markers desired=${desiredMarkerIds.length} loaded=$cargados removed=$eliminados active=${_markerIds.length}',
      stopwatch,
    );
  }

  /// Sincroniza edificios construidos en el visor 3D con el estado del juego.
  /// Solo remueve/carga los edificios que han cambiado para evitar parpadeos.
  Future<void> sincronizarEdificiosConstructores(
    Juego game, {
    Set<String> buildingIdsOcultos = const <String>{},
  }) async {
    if (!_visorListo || _visor3DController == null) return;

    final Stopwatch stopwatch = Stopwatch()..start();
    int cargados = 0;
    int eliminados = 0;

    // Agrupar edificios únicos por Property para no duplicar cargas
    final Map<Propiedad, String> propertyToCoord = {};
    for (final MapEntry<String, Propiedad> entry in game.edificios.entries) {
      final String coord = entry.key;
      final Propiedad property = entry.value;

      // Usar la primera coordenada de cada edificio como punto de carga
      if (!propertyToCoord.containsKey(property)) {
        propertyToCoord[property] = coord;
      }
    }

    final Map<String, Propiedad> desiredPropertiesById = <String, Propiedad>{};
    for (final MapEntry<Propiedad, String> entry in propertyToCoord.entries) {
      final Propiedad property = entry.key;
      final String buildingId = _buildingSceneId(property);
      desiredPropertiesById[buildingId] = property;
    }

    final Set<String> desiredBuildingIds = desiredPropertiesById.keys.toSet();
    final Set<String> staleBuildingIds = _builtBuildingIds
        .difference(desiredBuildingIds)
        .toSet();

    for (final String buildingId in staleBuildingIds) {
      await _visor3DController!.removeModel(buildingId);
      _builtBuildingIds.remove(buildingId);
      _hiddenPreviewBuildingIds.remove(buildingId);
      _olvidarModelo(buildingId);
      eliminados++;
    }

    _buildingIdByOccupiedCoord.clear();

    // Cargar solo edificios nuevos y refrescar propiedades ligeras en existentes.
    for (final MapEntry<Propiedad, String> entry in propertyToCoord.entries) {
      final Propiedad property = entry.key;
      final String coord = _buildingAnchorCoord(
        property,
        fallback: entry.value,
      );

      final String buildingId = _buildingSceneId(property);
      final String assetPath =
          'assets/models/building${property.template.id}.glb';

      if (!_builtBuildingIds.contains(buildingId)) {
        await _cargarModeloYEsperarListo(
          buildingId,
          () => _visor3DController!.loadModelOnTile(
            buildingId,
            assetPath,
            coord,
            yOffset: _buildingY,
          ),
        );
        _builtBuildingIds.add(buildingId);
        cargados++;
      }

      await _setModelRotationIfChanged(
        buildingId,
        property.rotationIndex,
        templateId: property.template.id,
      );
      await _setModelVisibleIfChanged(
        buildingId,
        !buildingIdsOcultos.contains(buildingId),
      );
      await _visor3DController!.syncBuildingClickColliders(
        buildingId,
        property.occupiedCoords,
      );
      await _setObjectClickableIfChanged(buildingId, true);
      await _applyBuildingStyleIfChanged(
        buildingId,
        outlineHex: _hexContornoPorTipo(property.template.type),
        roofHex: _hexColorJugador(property.ownerId),
      );
      for (final String occupiedCoord in property.occupiedCoords) {
        _buildingIdByOccupiedCoord[occupiedCoord] = buildingId;
      }
    }

    _logPerf(
      'sync buildings desired=${desiredBuildingIds.length} loaded=$cargados removed=$eliminados active=${_builtBuildingIds.length}',
      stopwatch,
    );
  }

  String _buildingAnchorCoord(Propiedad property, {required String fallback}) {
    return property.occupiedCoords.isEmpty
        ? fallback
        : property.occupiedCoords.first;
  }

  String _buildingSceneId(Propiedad property) {
    final String coordsKey = property.occupiedCoords.join('_');
    return 'built_p${property.ownerId}_${property.template.id}_$coordsKey';
  }

  String? buildingSceneIdEnCoordenada(Juego game, String coord) {
    final Propiedad? property = game.edificios[coord];
    if (property == null) {
      return null;
    }
    return _buildingSceneId(property);
  }

  Future<void> mostrarEdificioConstruido(String buildingId) async {
    if (!_visorListo || _visor3DController == null) return;
    await _setModelVisibleIfChanged(buildingId, true);
  }

  Future<void> mostrarPreviewEdificio(
    String coord, {
    required String modelPath,
    required String templateId,
    required int rotationIndex,
  }) async {
    if (!_visorListo || _visor3DController == null) return;

    await _cargarModeloYEsperarListo(
      previewEdificioId,
      () => _visor3DController!.loadModelOnTile(
        previewEdificioId,
        modelPath,
        coord,
        yOffset: _previewY,
      ),
    );
    await _visor3DController!.setModelRotation(
      previewEdificioId,
      0,
      _rotationIndexToRadians(rotationIndex, templateId: templateId),
      0,
    );
    //await _visor3DController!.setModelScale(previewEdificioId, 0.7, 0.7, 0.7);
    await _visor3DController!.setObjectClickable(previewEdificioId, false);
  }

  Future<void> actualizarRotacionPreviewEdificio(
    int rotationIndex, {
    required String templateId,
  }) async {
    if (!_visorListo || _visor3DController == null) return;
    await _visor3DController!.setModelRotation(
      previewEdificioId,
      0,
      _rotationIndexToRadians(rotationIndex, templateId: templateId),
      0,
    );
  }

  Future<void> ocultarPreviewEdificio() async {
    if (!_visorListo || _visor3DController == null) return;
    await _visor3DController!.removeModel(previewEdificioId);
    _olvidarModelo(previewEdificioId);
  }

  Future<void> asentarPreviewEdificio(String coord) async {
    if (!_visorListo || _visor3DController == null) return;

    await _visor3DController!.animateModelToTile(
      previewEdificioId,
      coord,
      yOffset: _buildingY,
      durationMs: _buildingDropDurationMs,
    );
    await Future<void>.delayed(
      const Duration(milliseconds: _buildingDropDurationMs),
    );
  }

  Future<void> ocultarEdificiosEnCoordenadas(Iterable<String> coords) async {
    if (!_visorListo || _visor3DController == null) return;

    final Set<String> idsToHide = <String>{};
    final Set<String> markerIdsToHide = <String>{};
    for (final String coord in coords) {
      final String? buildingId = _buildingIdByOccupiedCoord[coord];
      if (buildingId != null) {
        idsToHide.add(buildingId);
      }

      final String normalizedCoord = coord.toUpperCase().trim();
      for (final String markerId in _markerIds) {
        if (markerId.endsWith('_$normalizedCoord')) {
          markerIdsToHide.add(markerId);
        }
      }
    }

    final Set<String> buildingsToRestore = _hiddenPreviewBuildingIds
        .difference(idsToHide)
        .toSet();
    final Set<String> markersToRestore = _hiddenPreviewMarkerIds
        .difference(markerIdsToHide)
        .toSet();

    // Ocultamos primero lo nuevo y restauramos despues lo que ya no queda bajo
    // la preview. Asi evitamos un frame visible del marcador durante rotaciones.
    for (final String buildingId in idsToHide.difference(
      _hiddenPreviewBuildingIds,
    )) {
      await _setModelVisibleIfChanged(buildingId, false);
    }

    for (final String markerId in markerIdsToHide.difference(
      _hiddenPreviewMarkerIds,
    )) {
      await _setModelVisibleIfChanged(markerId, false);
    }

    for (final String buildingId in buildingsToRestore) {
      await _setModelVisibleIfChanged(buildingId, true);
    }

    for (final String markerId in markersToRestore) {
      if (_markerIds.contains(markerId)) {
        await _setModelVisibleIfChanged(markerId, true);
      }
    }

    _hiddenPreviewBuildingIds
      ..clear()
      ..addAll(idsToHide);
    _hiddenPreviewMarkerIds
      ..clear()
      ..addAll(markerIdsToHide);
  }

  Future<void> restaurarEdificiosOcultosPorPreview() async {
    if (!_visorListo || _visor3DController == null) return;

    for (final String buildingId in _hiddenPreviewBuildingIds) {
      await _setModelVisibleIfChanged(buildingId, true);
    }
    _hiddenPreviewBuildingIds.clear();

    for (final String markerId in _hiddenPreviewMarkerIds) {
      if (_markerIds.contains(markerId)) {
        await _setModelVisibleIfChanged(markerId, true);
      }
    }
    _hiddenPreviewMarkerIds.clear();
  }

  Future<void> colocarEdificioEnCasilla(
    String id,
    String coord, {
    required String modelPath,
    required String templateId,
    required int rotationIndex,
  }) async {
    if (!_visorListo || _visor3DController == null) return;

    await _cargarModeloYEsperarListo(
      id,
      () => _visor3DController!.loadModelOnTile(
        id,
        modelPath,
        coord,
        yOffset: _buildingY,
      ),
    );
    await _setModelRotationIfChanged(id, rotationIndex, templateId: templateId);
    //await _visor3DController!.setModelScale(id, 0.7, 0.7, 0.7);
    await _setObjectClickableIfChanged(id, true);
  }

  Future<void> _setModelRotationIfChanged(
    String id,
    int rotationIndex, {
    required String templateId,
  }) async {
    final int visualRotationKey = Object.hash(templateId, rotationIndex);
    if (_buildingRotationById[id] == visualRotationKey) {
      return;
    }

    await _visor3DController!.setModelRotation(
      id,
      0,
      _rotationIndexToRadians(rotationIndex, templateId: templateId),
      0,
    );
    _buildingRotationById[id] = visualRotationKey;
  }

  Future<void> _setModelVisibleIfChanged(String id, bool visible) async {
    if (_modelVisibleById[id] == visible) {
      return;
    }

    await _visor3DController!.setModelVisible(id, visible);
    _modelVisibleById[id] = visible;
  }

  Future<void> _setObjectClickableIfChanged(String id, bool clickable) async {
    if (_modelClickableById[id] == clickable) {
      return;
    }

    await _visor3DController!.setObjectClickable(id, clickable);
    _modelClickableById[id] = clickable;
  }

  Future<void> _applyBuildingStyleIfChanged(
    String id, {
    required String outlineHex,
    required String roofHex,
  }) async {
    final String styleKey = '$outlineHex|$roofHex';
    if (_buildingStyleById[id] == styleKey) {
      return;
    }

    await _visor3DController!.applyBuildingStyle(
      id,
      outlineHex: outlineHex,
      roofHex: roofHex,
    );
    _buildingStyleById[id] = styleKey;
  }

  void _olvidarModelo(String id) {
    _buildingRotationById.remove(id);
    _buildingStyleById.remove(id);
    _modelVisibleById.remove(id);
    _modelClickableById.remove(id);
  }

  void _resetSceneTracking() {
    _markerIds.clear();
    _builtBuildingIds.clear();
    _buildingIdByOccupiedCoord.clear();
    _hiddenPreviewBuildingIds.clear();
    _hiddenPreviewMarkerIds.clear();
    _buildingRotationById.clear();
    _buildingStyleById.clear();
    _modelVisibleById.clear();
    _modelClickableById.clear();
  }

  Future<void> _cargarModeloYEsperarListo(
    String modelId,
    Future<void> Function() loadAction,
  ) async {
    final I3DViewerController? controller = _visor3DController;
    if (!_visorListo || controller == null) return;

    final Stopwatch stopwatch = Stopwatch()..start();
    final Completer<void> loadedCompleter = Completer<void>();
    final void Function(String)? previousOnModelLoaded =
        controller.onModelLoaded;

    late final void Function(String) modelLoadedHandler;
    modelLoadedHandler = (String loadedId) {
      previousOnModelLoaded?.call(loadedId);
      if (loadedId == modelId && !loadedCompleter.isCompleted) {
        loadedCompleter.complete();
      }
    };

    controller.onModelLoaded = modelLoadedHandler;

    try {
      await loadAction();
      await loadedCompleter.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      debugPrint('⚠️ Timeout esperando carga de modelo: $modelId');
    } finally {
      if (identical(controller.onModelLoaded, modelLoadedHandler)) {
        controller.onModelLoaded = previousOnModelLoaded;
      }
      _logPerf('load model $modelId', stopwatch, warnAfterMs: 250);
    }
  }

  void _logPerf(String label, Stopwatch stopwatch, {int warnAfterMs = 80}) {
    stopwatch.stop();
    final int elapsedMs = stopwatch.elapsedMilliseconds;
    final String severity = elapsedMs >= warnAfterMs ? 'SLOW' : 'OK';
    debugPrint('[FOR PERF][$severity] $label ${elapsedMs}ms');
  }

  double _rotationIndexToRadians(
    int rotationIndex, {
    required String templateId,
  }) {
    final double baseRotation = -rotationIndex * (3.141592653589793 / 2.0);
    if (templateId == 'TemploVulcano') {
      return rotationIndex * (3.141592653589793 / 2.0);
    }
    if (templateId == 'TemploMinerva' && rotationIndex.isOdd) {
      return baseRotation + 3.141592653589793;
    }
    return baseRotation;
  }

  String _hexColorJugador(int playerId) {
    return ForColors.getPlayerColor(playerId).rgbHex;
  }

  String _hexContornoPorTipo(TipoEdificio type) {
    switch (type) {
      case TipoEdificio.civic:
        return '#FFFFFF';
      case TipoEdificio.residential:
        return '#F5E6C8';
      case TipoEdificio.commercial:
        return '#8B5E3C';
    }
  }

  /// Color del jugador en formato hexadecimal, para reutilizar en la UI 2D.
  String colorJugadorHex(int playerId) => _hexColorJugador(playerId);

  /// Salir de la aplicación
  void salirDeAplicacion() {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }
}
