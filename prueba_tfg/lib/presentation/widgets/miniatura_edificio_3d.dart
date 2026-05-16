import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../for_theme.dart';

const double _velocidadMiniatura = 0.5;

class MiniaturaEdificio3D extends StatefulWidget {
  const MiniaturaEdificio3D({required this.videoPath, super.key});

  final String videoPath;

  @override
  State<MiniaturaEdificio3D> createState() => _MiniaturaEdificio3DState();
}

class _MiniaturaEdificio3DState extends State<MiniaturaEdificio3D> {
  late VideoPlayerController _controller;
  bool _videoCargado = false;
  bool _controllerCreado = false;
  int _versionCarga = 0;

  @override
  void initState() {
    super.initState();
    _crearControlador();
  }

  @override
  void didUpdateWidget(covariant MiniaturaEdificio3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath == widget.videoPath) {
      return;
    }

    _versionCarga++;
    if (_controllerCreado) {
      unawaited(_controller.dispose());
    }
    setState(() {
      _videoCargado = false;
    });
    _crearControlador();
  }

  Future<void> _crearControlador() async {
    final int version = ++_versionCarga;
    final VideoPlayerController controller = VideoPlayerController.asset(
      widget.videoPath,
    );
    _controller = controller;
    _controllerCreado = true;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await _aplicarVelocidad(controller);
    } catch (error) {
      debugPrint(
        'No se pudo cargar miniatura de video ${widget.videoPath}: $error',
      );
      if (version == _versionCarga) {
        await controller.dispose();
      }
      return;
    }

    if (!mounted || version != _versionCarga) {
      await controller.dispose();
      return;
    }

    await controller.play();
    await _aplicarVelocidad(controller);
    unawaited(_reaplicarVelocidadTrasArranque(controller, version));
    setState(() {
      _videoCargado = true;
    });
  }

  Future<void> _aplicarVelocidad(VideoPlayerController controller) async {
    await controller.setPlaybackSpeed(_velocidadMiniatura);
  }

  Future<void> _reaplicarVelocidadTrasArranque(
    VideoPlayerController controller,
    int version,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || version != _versionCarga) {
      return;
    }
    await _aplicarVelocidad(controller);
  }

  @override
  void dispose() {
    _versionCarga++;
    if (_controllerCreado) {
      unawaited(_controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ForColors.thumbnailBackground,
        borderRadius: BorderRadius.circular(ForRadii.compactButton),
        border: Border.all(color: ForColors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ForRadii.compactButton),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_videoCargado)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            if (!_videoCargado)
              const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ForColors.gold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
