// Miniatura animada de edificios. Reproduce un video corto en bucle para
// enseñar el aspecto del edificio dentro de catalogos y paneles.

import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../for_theme.dart';

/// Velocidad de reproduccion usada por las miniaturas de edificios.
const double _velocidadMiniatura = 0.5;
const int _miniaturasVideoMaximasEnCache = 8;
const Duration _retencionMiniaturaInactiva = Duration(seconds: 12);
const Duration _esperaPrimerFrameVideo = Duration(milliseconds: 140);

bool get _usarSoloPoster =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<void> _aplicarVelocidadMiniatura(
  VideoPlayerController controller,
) async {
  await controller.setPlaybackSpeed(_velocidadMiniatura);
}

/// Widget que muestra una miniatura animada de un edificio.
class MiniaturaEdificio3D extends StatefulWidget {
  const MiniaturaEdificio3D({required this.videoPath, super.key});

  final String videoPath;

  @override
  State<MiniaturaEdificio3D> createState() => _MiniaturaEdificio3DState();
}

class _CacheMiniaturasVideo {
  static final Map<String, _EntradaMiniaturaVideo> _entradas =
      <String, _EntradaMiniaturaVideo>{};
  static int _usoActual = 0;

  static _EntradaMiniaturaVideo adquirir(String videoPath) {
    final _EntradaMiniaturaVideo entrada = _entradas.putIfAbsent(
      videoPath,
      () => _EntradaMiniaturaVideo(videoPath),
    );
    entrada.adquirir(++_usoActual);
    return entrada;
  }

  static void liberar(_EntradaMiniaturaVideo entrada) {
    entrada.liberar(++_usoActual);
    _programarLimpieza();
  }

  static void _programarLimpieza() {
    Future<void>.delayed(
      _retencionMiniaturaInactiva,
      _limpiarEntradasInactivas,
    );
  }

  static void _limpiarEntradasInactivas() {
    final List<_EntradaMiniaturaVideo> inactivas =
        _entradas.values
            .where(
              (_EntradaMiniaturaVideo entrada) =>
                  entrada.usuarios == 0 && entrada.inicializada,
            )
            .toList()
          ..sort(
            (_EntradaMiniaturaVideo a, _EntradaMiniaturaVideo b) =>
                a.ultimoUso.compareTo(b.ultimoUso),
          );

    final int inicializadas = _entradas.values
        .where((_EntradaMiniaturaVideo entrada) => entrada.inicializada)
        .length;
    int sobrantes = inicializadas - _miniaturasVideoMaximasEnCache;
    for (final _EntradaMiniaturaVideo entrada in inactivas) {
      if (sobrantes <= 0) {
        break;
      }
      _entradas.remove(entrada.videoPath);
      unawaited(entrada.dispose());
      sobrantes--;
    }
  }
}

class _EntradaMiniaturaVideo {
  _EntradaMiniaturaVideo(this.videoPath);

  final String videoPath;
  late final VideoPlayerController controller = VideoPlayerController.asset(
    videoPath,
  );
  Future<void>? _inicializacion;
  bool inicializada = false;
  bool _descartada = false;
  int usuarios = 0;
  int ultimoUso = 0;

  void adquirir(int uso) {
    usuarios++;
    ultimoUso = uso;
  }

  void liberar(int uso) {
    usuarios = (usuarios - 1).clamp(0, 1 << 20);
    ultimoUso = uso;
    if (inicializada && !_descartada) {
      unawaited(controller.pause());
    }
  }

  Future<void> inicializar() {
    return _inicializacion ??= _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      if (_descartada) {
        return;
      }
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await _aplicarVelocidadMiniatura(controller);
      inicializada = true;
    } catch (error) {
      debugPrint('No se pudo cargar miniatura de video $videoPath: $error');
      _inicializacion = null;
      rethrow;
    }
  }

  Future<void> dispose() async {
    _descartada = true;
    await controller.dispose();
  }
}

/// Estado encargado de cargar, reproducir y liberar el video de miniatura.
class _MiniaturaEdificio3DState extends State<MiniaturaEdificio3D> {
  _EntradaMiniaturaVideo? _entrada;
  bool _videoCargado = false;
  int _versionCarga = 0;

  @override
  void initState() {
    super.initState();
    if (_usarSoloPoster) {
      return;
    }
    _usarMiniaturaActual();
  }

  @override
  void didUpdateWidget(covariant MiniaturaEdificio3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath == widget.videoPath) {
      return;
    }

    if (_usarSoloPoster) {
      return;
    }
    _versionCarga++;
    _liberarEntradaActual();
    setState(() {
      _videoCargado = false;
    });
    _usarMiniaturaActual();
  }

  Future<void> _usarMiniaturaActual() async {
    final int version = ++_versionCarga;
    final _EntradaMiniaturaVideo entrada = _CacheMiniaturasVideo.adquirir(
      widget.videoPath,
    );
    _entrada = entrada;

    try {
      await entrada.inicializar();
    } catch (error) {
      return;
    }

    if (!mounted || version != _versionCarga || !entrada.inicializada) {
      return;
    }

    await entrada.controller.play();
    await _aplicarVelocidadMiniatura(entrada.controller);
    unawaited(_reaplicarVelocidadTrasArranque(entrada.controller, version));
    await Future<void>.delayed(_esperaPrimerFrameVideo);
    if (!mounted || version != _versionCarga || !entrada.inicializada) {
      return;
    }
    setState(() {
      _videoCargado = true;
    });
  }

  void _liberarEntradaActual() {
    final _EntradaMiniaturaVideo? entrada = _entrada;
    if (entrada == null) {
      return;
    }
    _entrada = null;
    _CacheMiniaturasVideo.liberar(entrada);
  }

  Future<void> _reaplicarVelocidadTrasArranque(
    VideoPlayerController controller,
    int version,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || version != _versionCarga) {
      return;
    }
    await _aplicarVelocidadMiniatura(controller);
  }

  @override
  void dispose() {
    _versionCarga++;
    _liberarEntradaActual();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ForColors.thumbnailBackground,
        borderRadius: BorderRadius.circular(ForRadius.compactButton),
        border: Border.all(color: ForColors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ForRadius.compactButton),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _posterPath,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.expand(),
            ),
            if (!_usarSoloPoster && _videoCargado)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _entrada!.controller.value.size.width,
                  height: _entrada!.controller.value.size.height,
                  child: VideoPlayer(_entrada!.controller),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get _posterPath {
    final int separatorIndex = widget.videoPath.lastIndexOf('/');
    final String directory = separatorIndex == -1
        ? ''
        : widget.videoPath.substring(0, separatorIndex + 1);
    final String fileName = separatorIndex == -1
        ? widget.videoPath
        : widget.videoPath.substring(separatorIndex + 1);
    final String baseName = fileName.endsWith('.mp4')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;

    return '${directory}posters/$baseName.webp';
  }
}
