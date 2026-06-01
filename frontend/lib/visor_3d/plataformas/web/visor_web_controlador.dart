// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

// Controlador web del visor 3D. Crea iframes HTML, registra HtmlElementView y
// envia comandos a Three.js mediante postMessage.

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import '../../interfaz_controlador.dart';
import '../../camara_config.dart';
import '../../escena_threejs.dart';

/// Controlador Three.js para web via iframe y postMessage.
class _WebThreeJsControllerImpl implements I3DViewerController {
  final Completer<void> _initialized = Completer();
  html.IFrameElement? _iframe;

  void _markReady() {
    if (!_initialized.isCompleted) _initialized.complete();
  }

  void setIframe(html.IFrameElement iframe) {
    _iframe = iframe;
  }

  void _sendCommand(String command) {
    _iframe?.contentWindow?.postMessage(command, '*');
  }

  @override
  void Function(String)? onModelLoaded;

  @override
  void Function(String)? onError;

  @override
  void Function(String)? onObjectClicked;

  @override
  Future<void> setCameraOrbit(
    double roll,
    double pitch,
    double distance,
  ) async {
    await _ensureReady();
    _sendCommand('setCameraOrbit:$roll:$pitch:$distance');
  }

  @override
  Future<void> setCameraTarget(double x, double y, double z) async {
    await _ensureReady();
    _sendCommand('setCameraTarget:$x:$y:$z');
  }

  @override
  Future<void> resetCamera() async {
    await _ensureReady();
    _sendCommand('resetCamera');
  }

  @override
  Future<void> loadModel(
    String id,
    String url, {
    double x = 0,
    double y = 0,
    double z = 0,
  }) async {
    await _ensureReady();
    _sendCommand('loadModel:$id:${_webAssetUrl(url)}:$x:$y:$z');
  }

  @override
  Future<void> removeModel(String id) async {
    await _ensureReady();
    _sendCommand('removeModel:$id');
  }

  @override
  Future<void> setModelPosition(String id, double x, double y, double z) async {
    await _ensureReady();
    _sendCommand('setModelPosition:$id:$x:$y:$z');
  }

  @override
  Future<void> animateModelToTile(
    String id,
    String coord, {
    double yOffset = 0,
    int durationMs = 220,
  }) async {
    await _ensureReady();
    _sendCommand('animateModelToTile:$id:$coord:$yOffset:$durationMs');
  }

  @override
  Future<void> setModelRotation(
    String id,
    double rx,
    double ry,
    double rz,
  ) async {
    await _ensureReady();
    _sendCommand('setModelRotation:$id:$rx:$ry:$rz');
  }

  @override
  Future<void> setModelScale(String id, double sx, double sy, double sz) async {
    await _ensureReady();
    _sendCommand('setModelScale:$id:$sx:$sy:$sz');
  }

  @override
  Future<void> setModelVisible(String id, bool visible) async {
    await _ensureReady();
    _sendCommand('setModelVisible:$id:$visible');
  }

  @override
  Future<void> createMarkerCube(
    String id, {
    required double x,
    required double y,
    required double z,
    required double size,
    required String colorHex,
  }) async {
    await _ensureReady();
    _sendCommand('createMarkerCube:$id:$x:$y:$z:$size:$colorHex');
  }

  @override
  Future<void> createMarkerCubeOnTile(
    String id,
    String coord, {
    required double yOffset,
    required double size,
    required String colorHex,
  }) async {
    await _ensureReady();
    _sendCommand('createMarkerCubeOnTile:$id:$coord:$yOffset:$size:$colorHex');
  }

  @override
  Future<void> loadModelOnTile(
    String id,
    String url,
    String coord, {
    double yOffset = 0,
  }) async {
    await _ensureReady();
    _sendCommand('loadModelOnTile:$id:${_webAssetUrl(url)}:$coord:$yOffset');
  }

  @override
  Future<void> setObjectClickable(String id, bool clickable) async {
    await _ensureReady();
    _sendCommand('setObjectClickable:$id:$clickable');
  }

  @override
  Future<void> syncBuildingClickColliders(
    String buildingId,
    List<String> coords,
  ) async {
    await _ensureReady();
    _sendCommand('syncBuildingClickColliders:$buildingId:${coords.join(',')}');
  }

  @override
  Future<void> applyBuildingStyle(
    String id, {
    required String outlineHex,
    required String roofHex,
  }) async {
    await _ensureReady();
    _sendCommand('applyBuildingStyle:$id:$outlineHex:$roofHex');
  }

  @override
  Future<void> playAnimation(String modelId, String animationName) async {
    await _ensureReady();
    _sendCommand('playAnimation:$modelId:$animationName');
  }

  @override
  Future<void> pauseAnimation(String modelId) async {
    await _ensureReady();
    _sendCommand('pauseAnimation:$modelId');
  }

  @override
  Future<List<String>> getAvailableAnimations(String modelId) async {
    return [];
  }

  @override
  Future<void> dispose() async {
    _iframe = null;
  }

  Future<void> _ensureReady() async {
    if (!_initialized.isCompleted) {
      await _initialized.future.timeout(
        VisorConfig.loadTimeout,
        onTimeout: () {},
      );
    }
  }
}

String _webAssetUrl(String url) {
  if (url.isEmpty || url.startsWith('http') || url.startsWith('/')) {
    return url;
  }
  if (url.startsWith('assets/')) {
    return '/assets/$url';
  }
  return url;
}

/// Contador global para generar IDs únicos de view factories
int _viewFactoryCounter = 0;

/// Crea un iframe con Three.js y lo registra como HtmlElementView
/// Retorna el viewType para usarlo en HtmlElementView
String? setupWebViewer(
  String modelPath,
  Completer<I3DViewerController> controllerCompleter,
  bool interactive,
  bool loadScenario,
  String? backgroundColorHex,
  bool renderContinuously,
  bool isThumbnail,
) {
  final viewType = 'threejs-viewer-${_viewFactoryCounter++}';
  final controller = _WebThreeJsControllerImpl();
  final htmlContent = buildThreeJsHtml(
    modelPath,
    scenarioModelUrl: loadScenario ? VisorConfig.scenarioModelPath : '',
    backgroundColorHex: backgroundColorHex,
    renderContinuously: renderContinuously,
    isThumbnail: isThumbnail,
  );

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..srcdoc = htmlContent
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.margin = '0'
      ..style.padding = '0'
      ..style.pointerEvents = interactive ? 'auto' : 'none'
      ..allow = 'autoplay';

    controller.setIframe(iframe);
    return iframe;
  });

  // Escuchar mensajes del iframe
  html.window.onMessage.listen((event) {
    final data = event.data;
    if (data is String) {
      if (data.startsWith('modelLoaded:')) {
        final id = data.replaceFirst('modelLoaded:', '');
        controller._markReady();
        controller.onModelLoaded?.call(id);
      } else if (data.startsWith('objectClicked:')) {
        final id = data.replaceFirst('objectClicked:', '');
        controller.onObjectClicked?.call(id);
      } else if (data.startsWith('error:')) {
        final error = data.replaceFirst('error:', '');
        controller.onError?.call(error);
      }
    }
  });

  controllerCompleter.complete(controller);
  return viewType;
}
