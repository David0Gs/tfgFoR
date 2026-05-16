import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../infrastructure/audio/audio_service.dart';
import '../for_theme.dart';

const String _assetAgradecimientos = 'assets/texts/agradecimientos.txt';
const String _urlManualReglas =
    'https://www.arcanewonders.com/wp-content/uploads/2021/05/FoR-Core-Rulebook-Spanish_web.pdf';
const String _urlVideotutorial =
    'https://www.youtube.com/watch?v=my8_V8Rcryg&autoplay=1&wide=1';

class PantallaMenuPrincipal extends StatelessWidget {
  const PantallaMenuPrincipal({
    required this.onIniciarPartidaLocal,
    required this.onCargarPartida,
    required this.onConectarPartidaRemota,
    required this.onMostrarRanking,
    super.key,
  });

  final Future<void> Function(BuildContext context) onIniciarPartidaLocal;
  final Future<void> Function(BuildContext context) onCargarPartida;
  final Future<void> Function(BuildContext context) onConectarPartidaRemota;
  final Future<void> Function(BuildContext context) onMostrarRanking;

  static const List<_MenuOption> _opciones = <_MenuOption>[
    _MenuOption('Iniciar partida local', _MenuAction.iniciarPartidaLocal),
    _MenuOption('Cargar partida', _MenuAction.cargarPartida),
    _MenuOption('Conectar a partida remota', _MenuAction.conectarPartidaRemota),
    _MenuOption('Ranking', _MenuAction.ranking),
    _MenuOption('Manual de reglas', _MenuAction.manualReglas),
    _MenuOption('Videotutorial', _MenuAction.videotutorial),
    _MenuOption('Agradecimientos, y créditos', _MenuAction.agradecimientos),
  ];

  Future<void> _manejarOpcion(BuildContext context, _MenuOption opcion) async {
    switch (opcion.action) {
      case _MenuAction.iniciarPartidaLocal:
        await onIniciarPartidaLocal(context);
      case _MenuAction.cargarPartida:
        await onCargarPartida(context);
      case _MenuAction.conectarPartidaRemota:
        await onConectarPartidaRemota(context);
      case _MenuAction.ranking:
        await onMostrarRanking(context);
      case _MenuAction.manualReglas:
        await _abrirEnlace(
          context,
          url: _urlManualReglas,
          error: 'No se pudo abrir el manual de reglas.',
        );
      case _MenuAction.videotutorial:
        await _abrirEnlace(
          context,
          url: _urlVideotutorial,
          error: 'No se pudo abrir el videotutorial.',
        );
      case _MenuAction.agradecimientos:
        await _mostrarDialogoAgradecimientos(context);
    }
  }

  Future<void> _mostrarDialogoAgradecimientos(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierColor: ForColors.overlayStrong,
      builder: (BuildContext dialogContext) {
        final Size size = MediaQuery.of(dialogContext).size;
        final Future<String> contenidoFuture = DefaultAssetBundle.of(
          dialogContext,
        ).loadString(_assetAgradecimientos);

        return Dialog(
          backgroundColor: ForColors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 32,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: size.height * 0.8,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ForRadii.dialog),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    ForColors.dialogGradientTop,
                    ForColors.dialogGradientMid,
                    ForColors.dialogGradientBottom,
                  ],
                ),
                border: Border.all(color: ForColors.dialogFrame, width: 1.6),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: ForColors.shadow,
                    blurRadius: 28,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ForRadii.dialog - 2),
                  color: ForColors.panel,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Agradecimientos, y créditos',
                                style: ForTypography.dialogTitle,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: ForButtonStyles.icon(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          color: ForColors.panelDark,
                          borderRadius: BorderRadius.circular(
                            ForRadii.contentPanel,
                          ),
                          border: Border.all(color: ForColors.borderSoft),
                        ),
                        child: FutureBuilder<String>(
                          future: contenidoFuture,
                          builder:
                              (
                                BuildContext context,
                                AsyncSnapshot<String> snapshot,
                              ) {
                                if (snapshot.connectionState !=
                                    ConnectionState.done) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(32),
                                      child: CircularProgressIndicator(
                                        color: ForColors.goldLight,
                                      ),
                                    ),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                        'No se pudo cargar el contenido temporal de agradecimientos.',
                                        textAlign: TextAlign.center,
                                        style: ForTypography.alertTitle,
                                      ),
                                    ),
                                  );
                                }

                                return _CreditosPanel(
                                  texto: snapshot.data!.trim(),
                                );
                              },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirEnlace(
    BuildContext context, {
    required String url,
    required String error,
  }) async {
    final bool abierto = await launchUrl(
      Uri.parse(url),
      webOnlyWindowName: '_blank',
    );
    if (abierto || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  bool _muestraIconoEnlace(_MenuOption opcion) {
    return opcion.action == _MenuAction.manualReglas ||
        opcion.action == _MenuAction.videotutorial;
  }

  @override
  Widget build(BuildContext context) {
    const double menuMinWidth = 280;
    const double menuMaxWidth = 420;
    const double topSpacing = 64;
    const double bottomSpacing = 32;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/pics/forScreen.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double availableHeight =
                      constraints.maxHeight - topSpacing - bottomSpacing;
                  final double minContentHeight = availableHeight > 0
                      ? availableHeight
                      : 0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      topSpacing,
                      24,
                      bottomSpacing,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minContentHeight),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: menuMinWidth,
                            maxWidth: menuMaxWidth,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.rotate(
                                angle: 0.785398,
                                child: Image.asset(
                                  'assets/pics/forIcon.png',
                                  width: 180,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 54),
                              ..._opciones.map(
                                (_MenuOption opcion) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _manejarOpcion(context, opcion);
                                      },
                                      style: ForButtonStyles.menuPrimary(),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              opcion.label,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          if (_muestraIconoEnlace(opcion)) ...[
                                            const SizedBox(width: 10),
                                            const Icon(
                                              Icons.open_in_new,
                                              size: 18,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 16,
                right: 16,
                child: ValueListenableBuilder<bool>(
                  valueListenable: AudioService.instance.isMuted,
                  builder: (BuildContext context, bool isMuted, Widget? child) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: ForColors.panelSoft,
                        borderRadius: BorderRadius.circular(ForRadii.button),
                        border: Border.all(color: ForColors.border),
                      ),
                      child: IconButton(
                        tooltip: isMuted
                            ? 'Activar musica'
                            : 'Silenciar musica',
                        onPressed: () async {
                          await AudioService.instance.toggleMuted();
                        },
                        icon: Icon(
                          isMuted ? Icons.volume_off : Icons.volume_up,
                          color: ForColors.text,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuOption {
  const _MenuOption(this.label, this.action);

  final String label;
  final _MenuAction action;
}

enum _MenuAction {
  iniciarPartidaLocal,
  cargarPartida,
  conectarPartidaRemota,
  ranking,
  manualReglas,
  videotutorial,
  agradecimientos,
}

class _CreditosPanel extends StatefulWidget {
  const _CreditosPanel({required this.texto});

  final String texto;

  @override
  State<_CreditosPanel> createState() => _CreditosPanelState();
}

class _CreditosPanelState extends State<_CreditosPanel> {
  late final ScrollController _scrollController;
  bool _autoScrollProgramado = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _programarAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _CreditosPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.texto != widget.texto) {
      _autoScrollProgramado = false;
      _programarAutoScroll();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _programarAutoScroll() {
    if (_autoScrollProgramado) {
      return;
    }

    _autoScrollProgramado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final double maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) {
        return;
      }

      _scrollController.jumpTo(0);
      _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: _duracionAutoScroll(maxScroll)),
        curve: Curves.linear,
      );
    });
  }

  int _duracionAutoScroll(double distancia) {
    final int duracion = (distancia * 24).round();
    if (duracion < 14000) {
      return 14000;
    }
    if (duracion > 48000) {
      return 48000;
    }
    return duracion;
  }

  @override
  Widget build(BuildContext context) {
    final List<_LineaCredito> lineas = _parsearLineasCredito(widget.texto);

    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ForRadii.contentPanel),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xFF080808),
                Color(0xFF16110D),
                Color(0xFF24180F),
              ],
            ),
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 88, 24, 44),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [...lineas.map(_construirLinea)],
                  ),
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Column(
            children: [
              Container(
                height: 34,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(ForRadii.contentPanel),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFF080808), Color(0x00080808)],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                height: 34,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(ForRadii.contentPanel),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x0024180F), Color(0xFF24180F)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirLinea(_LineaCredito linea) {
    switch (linea.tipo) {
      case _TipoLineaCredito.hero:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            linea.texto!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ForColors.goldLight,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: 1.2,
            ),
          ),
        );
      case _TipoLineaCredito.subtitle:
        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Text(
            linea.texto!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ForColors.goldPale,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.4,
              letterSpacing: 1.6,
            ),
          ),
        );
      case _TipoLineaCredito.section:
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 14),
          child: Text(
            linea.texto!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ForColors.goldPale,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
        );
      case _TipoLineaCredito.entry:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              Text(
                linea.etiqueta!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ForColors.parchmentDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                linea.texto!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ForColors.parchment,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      case _TipoLineaCredito.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            linea.texto!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ForColors.parchment,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.7,
            ),
          ),
        );
      case _TipoLineaCredito.spacer:
        return const SizedBox(height: 14);
    }
  }
}

List<_LineaCredito> _parsearLineasCredito(String texto) {
  final List<_LineaCredito> resultado = <_LineaCredito>[];
  int indiceContenido = 0;

  for (final String lineaBruta in texto.split('\n')) {
    final String linea = lineaBruta.trim();
    if (linea.isEmpty) {
      if (resultado.isNotEmpty &&
          resultado.last.tipo != _TipoLineaCredito.spacer) {
        resultado.add(const _LineaCredito.spacer());
      }
      continue;
    }

    indiceContenido += 1;
    if (indiceContenido == 1) {
      resultado.add(_LineaCredito.hero(linea));
      continue;
    }
    if (indiceContenido == 2) {
      resultado.add(_LineaCredito.subtitle(linea));
      continue;
    }
    if (_esCabeceraDeCredito(linea)) {
      resultado.add(_LineaCredito.section(linea.replaceAll(':', '')));
      continue;
    }

    final int indiceSeparador = linea.indexOf(':');
    if (indiceSeparador > 0) {
      final String etiqueta = linea.substring(0, indiceSeparador).trim();
      final String contenido = linea.substring(indiceSeparador + 1).trim();
      if (contenido.isNotEmpty && etiqueta.length <= 42) {
        resultado.add(
          _LineaCredito.entry(
            etiqueta: etiqueta.toUpperCase(),
            texto: contenido,
          ),
        );
        continue;
      }
    }

    resultado.add(_LineaCredito.paragraph(linea));
  }

  if (resultado.isNotEmpty && resultado.last.tipo == _TipoLineaCredito.spacer) {
    resultado.removeLast();
  }

  return resultado;
}

bool _esCabeceraDeCredito(String linea) {
  return linea.endsWith(':') && linea == linea.toUpperCase();
}

enum _TipoLineaCredito { hero, subtitle, section, entry, paragraph, spacer }

class _LineaCredito {
  const _LineaCredito.hero(this.texto)
    : tipo = _TipoLineaCredito.hero,
      etiqueta = null;

  const _LineaCredito.subtitle(this.texto)
    : tipo = _TipoLineaCredito.subtitle,
      etiqueta = null;

  const _LineaCredito.section(this.texto)
    : tipo = _TipoLineaCredito.section,
      etiqueta = null;

  const _LineaCredito.entry({required this.etiqueta, required this.texto})
    : tipo = _TipoLineaCredito.entry;

  const _LineaCredito.paragraph(this.texto)
    : tipo = _TipoLineaCredito.paragraph,
      etiqueta = null;

  const _LineaCredito.spacer()
    : tipo = _TipoLineaCredito.spacer,
      texto = null,
      etiqueta = null;

  final _TipoLineaCredito tipo;
  final String? texto;
  final String? etiqueta;
}
