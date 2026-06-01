// Visor 3D para movil. Sirve los assets Flutter desde un servidor HTTP local y
// los renderiza con Three.js dentro de InAppWebView.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../presentation/for_theme.dart';
import '../interfaz_controlador.dart';
import '../camara_config.dart';
import '../escena_threejs.dart';

/// Widget visor mobile usando InAppWebView y Three.js.
class MobileViewerWidget extends StatefulWidget {
  final String modelPath;
  final Completer<I3DViewerController> controllerCompleter;
  final bool interactive;
  final bool loadScenario;
  final String? backgroundColorHex;
  final bool renderContinuously;
  final bool isThumbnail;

  const MobileViewerWidget({
    super.key,
    required this.modelPath,
    required this.controllerCompleter,
    this.interactive = true,
    this.loadScenario = true,
    this.backgroundColorHex,
    this.renderContinuously = false,
    this.isThumbnail = false,
  });

  @override
  State<MobileViewerWidget> createState() => _MobileViewerWidgetState();
}

/// Estado que inicia el servidor local y monta el WebView movil.
class _MobileViewerWidgetState extends State<MobileViewerWidget> {
  late _ThreeJsControllerImpl _impl;
  HttpServer? _server;
  String? _serverUrl;
  bool _ready = false;

  Color get _backgroundColor => widget.loadScenario
      ? VisorConfig.backgroundColor
      : VisorConfig.thumbnailBackgroundColor;

  @override
  void initState() {
    super.initState();
    _impl = _ThreeJsControllerImpl();
    _startLocalServer();
  }

  Future<void> _startLocalServer() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final String baseUrl = 'http://127.0.0.1:${_server!.port}';
    _serverUrl = baseUrl;

    final String modelUrl = widget.modelPath.startsWith('http')
        ? widget.modelPath
        : '$baseUrl/${widget.modelPath}';
    final String scenarioModelUrl = widget.loadScenario
        ? '$baseUrl/${VisorConfig.scenarioModelPath}'
        : '';

    final String htmlContent = buildThreeJsHtml(
      modelUrl,
      scenarioModelUrl: scenarioModelUrl,
      assetBasePath: '$baseUrl/assets',
      backgroundColorHex: widget.backgroundColorHex,
      renderContinuously: widget.renderContinuously,
      isThumbnail: widget.isThumbnail,
      maxPixelRatio: 1.25,
      lowPowerMode: true,
    );

    _server!.listen((HttpRequest request) async {
      final String path = request.uri.path;

      if (path == '/' || path.isEmpty) {
        request.response
          ..headers.contentType = ContentType.html
          ..write(htmlContent)
          ..close();
        return;
      }

      final String cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final Uint8List? data = await _loadAssetBytes(cleanPath);

      if (data == null) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found: $cleanPath')
          ..close();
        return;
      }

      request.response
        ..headers.contentType = _contentTypeFromExtension(cleanPath)
        ..headers.add('Access-Control-Allow-Origin', '*')
        ..headers.add('Cache-Control', 'public, max-age=31536000, immutable');
      request.response.add(data);
      await request.response.close();
    });

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  Future<Uint8List?> _loadAssetBytes(String assetPath) async {
    try {
      final ByteData bytes = await rootBundle.load(assetPath);
      return bytes.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  ContentType _contentTypeFromExtension(String path) {
    final String ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'glb' => ContentType('model', 'gltf-binary'),
      'gltf' => ContentType('model', 'gltf+json'),
      'json' => ContentType.json,
      'png' => ContentType('image', 'png'),
      'webp' => ContentType('image', 'webp'),
      'jpg' || 'jpeg' => ContentType('image', 'jpeg'),
      'js' => ContentType('application', 'javascript'),
      'html' => ContentType.html,
      _ => ContentType.binary,
    };
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Container(
        color: _backgroundColor,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: VisorConfig.progressColor),
              SizedBox(height: 16),
              Text(
                'Iniciando motor 3D...',
                style: TextStyle(color: ForColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: Container(
        color: _backgroundColor,
        child: IgnorePointer(
          ignoring: !widget.interactive,
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_serverUrl!)),
            initialSettings: InAppWebViewSettings(
              transparentBackground: false,
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
            ),
            onWebViewCreated: (InAppWebViewController controller) {
              _impl.setWebView(controller);
              controller.addJavaScriptHandler(
                handlerName: 'onThreeJsMessage',
                callback: (args) {
                  if (args.isNotEmpty) {
                    _handleMessage(args[0].toString());
                  }
                },
              );
            },
            onLoadStop: (controller, url) {
              if (!widget.controllerCompleter.isCompleted) {
                widget.controllerCompleter.complete(_impl);
              }
            },
            onConsoleMessage: (_, msg) {
              debugPrint('[Three.js Mobile] ${msg.message}');
            },
          ),
        ),
      ),
    );
  }

  void _handleMessage(String message) {
    if (message.startsWith('modelLoaded:')) {
      final String id = message.replaceFirst('modelLoaded:', '');
      _impl.onModelLoaded?.call(id);
    } else if (message.startsWith('objectClicked:')) {
      final String id = message.replaceFirst('objectClicked:', '');
      _impl.onObjectClicked?.call(id);
    } else if (message.startsWith('error:')) {
      final String error = message.replaceFirst('error:', '');
      _impl.onError?.call(error);
    } else if (message.startsWith('perf:3d:')) {
      debugPrint('[FOR PERF][3D] ${message.replaceFirst('perf:3d:', '')}');
    }
  }
}

/// Implementacion de I3DViewerController para Three.js via InAppWebView movil.
class _ThreeJsControllerImpl implements I3DViewerController {
  InAppWebViewController? _webView;
  final Completer<void> _ready = Completer<void>();

  void setWebView(InAppWebViewController controller) {
    _webView = controller;
    if (!_ready.isCompleted) {
      _ready.complete();
    }
  }

  Future<void> _sendCommand(String command) async {
    await _ready.future;
    await _webView?.evaluateJavascript(source: "handleCommand('$command');");
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
    await _sendCommand('setCameraOrbit:$roll:$pitch:$distance');
  }

  @override
  Future<void> setCameraTarget(double x, double y, double z) async {
    await _sendCommand('setCameraTarget:$x:$y:$z');
  }

  @override
  Future<void> resetCamera() async {
    await _sendCommand('resetCamera');
  }

  @override
  Future<void> loadModel(
    String id,
    String url, {
    double x = 0,
    double y = 0,
    double z = 0,
  }) async {
    await _sendCommand('loadModel:$id:$url:$x:$y:$z');
  }

  @override
  Future<void> removeModel(String id) async {
    await _sendCommand('removeModel:$id');
  }

  @override
  Future<void> setModelPosition(String id, double x, double y, double z) async {
    await _sendCommand('setModelPosition:$id:$x:$y:$z');
  }

  @override
  Future<void> animateModelToTile(
    String id,
    String coord, {
    double yOffset = 0,
    int durationMs = 220,
  }) async {
    await _sendCommand('animateModelToTile:$id:$coord:$yOffset:$durationMs');
  }

  @override
  Future<void> setModelRotation(
    String id,
    double rx,
    double ry,
    double rz,
  ) async {
    await _sendCommand('setModelRotation:$id:$rx:$ry:$rz');
  }

  @override
  Future<void> setModelScale(String id, double sx, double sy, double sz) async {
    await _sendCommand('setModelScale:$id:$sx:$sy:$sz');
  }

  @override
  Future<void> setModelVisible(String id, bool visible) async {
    await _sendCommand('setModelVisible:$id:$visible');
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
    await _sendCommand('createMarkerCube:$id:$x:$y:$z:$size:$colorHex');
  }

  @override
  Future<void> createMarkerCubeOnTile(
    String id,
    String coord, {
    required double yOffset,
    required double size,
    required String colorHex,
  }) async {
    await _sendCommand(
      'createMarkerCubeOnTile:$id:$coord:$yOffset:$size:$colorHex',
    );
  }

  @override
  Future<void> loadModelOnTile(
    String id,
    String url,
    String coord, {
    double yOffset = 0,
  }) async {
    await _sendCommand('loadModelOnTile:$id:$url:$coord:$yOffset');
  }

  @override
  Future<void> setObjectClickable(String id, bool clickable) async {
    await _sendCommand('setObjectClickable:$id:$clickable');
  }

  @override
  Future<void> syncBuildingClickColliders(
    String buildingId,
    List<String> coords,
  ) async {
    await _sendCommand(
      'syncBuildingClickColliders:$buildingId:${coords.join(',')}',
    );
  }

  @override
  Future<void> applyBuildingStyle(
    String id, {
    required String outlineHex,
    required String roofHex,
  }) async {
    await _sendCommand('applyBuildingStyle:$id:$outlineHex:$roofHex');
  }

  @override
  Future<void> playAnimation(String modelId, String animationName) async {
    await _sendCommand('playAnimation:$modelId:$animationName');
  }

  @override
  Future<void> pauseAnimation(String modelId) async {
    await _sendCommand('pauseAnimation:$modelId');
  }

  @override
  Future<List<String>> getAvailableAnimations(String modelId) async {
    return [];
  }

  @override
  Future<void> dispose() async {
    _webView = null;
  }
}
