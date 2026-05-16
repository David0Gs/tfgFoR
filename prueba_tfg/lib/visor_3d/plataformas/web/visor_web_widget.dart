import 'dart:async';
import 'package:flutter/material.dart';
import '../../../presentation/for_theme.dart';
import '../../interfaz_controlador.dart';
import '../../camara_config.dart';

/// Widget para visualizar modelos 3D en web usando Three.js en iframe
/// Se instancia solo en plataforma web (ver factory_plataforma.dart)
class WebViewerWidget extends StatefulWidget {
  final String modelPath;
  final Completer<I3DViewerController> controllerCompleter;
  final bool interactive;
  final bool loadScenario;
  final String? backgroundColorHex;
  final bool renderContinuously;
  final bool isThumbnail;

  const WebViewerWidget({
    super.key,
    required this.modelPath,
    required this.controllerCompleter,
    this.interactive = true,
    this.loadScenario = true,
    this.backgroundColorHex,
    this.renderContinuously = true,
    this.isThumbnail = false,
  });

  /// Callback de setup inyectado desde inicializador_web
  /// Retorna el viewType para HtmlElementView
  static String? Function(
    String,
    Completer<I3DViewerController>,
    bool,
    bool,
    String?,
    bool,
    bool,
  )?
  webSetupCallback;

  /// Inyecta el callback de setup
  static void injectWebSetup(
    String? Function(
      String,
      Completer<I3DViewerController>,
      bool,
      bool,
      String?,
      bool,
      bool,
    )
    callback,
  ) {
    webSetupCallback = callback;
  }

  @override
  State<WebViewerWidget> createState() => _WebViewerWidgetState();
}

class _WebViewerWidgetState extends State<WebViewerWidget> {
  String? _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = WebViewerWidget.webSetupCallback?.call(
      widget.modelPath,
      widget.controllerCompleter,
      widget.interactive,
      widget.loadScenario,
      widget.backgroundColorHex,
      widget.renderContinuously,
      widget.isThumbnail,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_viewType == null) {
      return Container(
        color: widget.loadScenario
            ? VisorConfig.backgroundColor
            : VisorConfig.thumbnailBackgroundColor,
        child: const Center(
          child: Text(
            'Error: viewer no inicializado',
            style: TextStyle(color: ForColors.text),
          ),
        ),
      );
    }
    return HtmlElementView(viewType: _viewType!);
  }
}
