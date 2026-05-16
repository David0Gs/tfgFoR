import 'dart:async';
import 'package:flutter/material.dart';
import 'factory_plataforma.dart';
import 'interfaz_controlador.dart';
import 'camara_config.dart';
import '../controlador_tablero.dart';
import '../presentation/for_theme.dart';

/// Widget principal del visor 3D multiplataforma
/// Usa factory pattern para elegir automáticamente el motor gráfico correcto
class Visor3D extends StatefulWidget {
  /// Controlador del tablero que gestiona la lógica del juego
  final TableroController controller;

  /// Ruta o URL del modelo 3D a cargar (GLB/GLTF)
  final String modelPath;

  /// Callback para notificar cuando el tablero activo ya esta cargado.
  final ValueChanged<String>? onModelLoaded;

  const Visor3D({
    super.key,
    required this.controller,
    required this.modelPath,
    this.onModelLoaded,
  });

  @override
  State<Visor3D> createState() => _Visor3DState();
}

class _Visor3DState extends State<Visor3D> {
  late Visor3DFactory _factory;
  late Completer<I3DViewerController> _controllerCompleter;
  I3DViewerController? _viewerController;
  bool _modeloCargado = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _factory = Visor3DFactory();
    _controllerCompleter = Completer<I3DViewerController>();
    _inicializarVisor();
  }

  /// Inicializa el visor y configura los callbacks
  void _inicializarVisor() {
    debugPrint("🎮 Inicializando visor 3D...");
    debugPrint("📱 Plataforma: ${_factory.currentEngine}");

    // Esperar a que el factory complete el controller
    _controllerCompleter.future
        .then((controller) {
          _viewerController = controller;
          _configurarCallbacks(controller);
          widget.controller.setVisor3DController(controller);
        })
        .catchError((Object error) {
          _handleError(error.toString());
        });
  }

  void _configurarCallbacks(I3DViewerController controller) {
    controller
      ..onModelLoaded = _handleModeloListo
      ..onError = _handleError;
  }

  /// Callback cuando el modelo se carga correctamente
  void _handleModeloListo(String modelPath) {
    if (modelPath == 'main') {
      setState(() {
        _modeloCargado = true;
        _errorMessage = null;
      });
    }
    widget.onModelLoaded?.call(modelPath);
  }

  /// Callback cuando hay un error
  void _handleError(String error) {
    setState(() {
      _errorMessage = error;
    });
    debugPrint("❌ Error en visor 3D: $error");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error cargando modelo: $error"),
          backgroundColor: ForColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    _viewerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget viewerWidget = KeyedSubtree(
      key: ValueKey<String>(widget.modelPath),
      child: _factory.createViewerWidget(
        modelPath: widget.modelPath,
        controllerCompleter: _controllerCompleter,
        renderContinuously: false,
      ),
    );

    return SizedBox.expand(
      child: Stack(
        children: [
          // Widget visor dinámico según plataforma
          viewerWidget,

          // Overlay de carga
          if (!_modeloCargado && _errorMessage == null)
            Container(
              color: ForColors.overlayMedium,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: VisorConfig.progressColor,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Cargando modelo 3D...",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: ForColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Motor: ${_factory.currentEngine}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ForColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Overlay de error
          if (_errorMessage != null)
            Container(
              color: ForColors.overlayHeavy,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: ForColors.error,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Error al cargar el modelo 3D",
                      style: TextStyle(
                        color: ForColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ForColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _errorMessage = null);
                        _modeloCargado = false;
                        _inicializarVisor();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text("Reintentar"),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
