// Panel que carga y muestra texto largo de creditos desde assets. Incluye
// estado de carga, error y scroll para contenido extenso.

import 'package:flutter/material.dart';

import '../for_theme.dart';

/// Panel reutilizable para mostrar un archivo de texto dentro de la interfaz.
class CreditosPanel extends StatefulWidget {
  const CreditosPanel({required this.texto, this.compact = false, super.key});

  final String texto;
  final bool compact;

  @override
  State<CreditosPanel> createState() => _CreditosPanelState();
}

/// Estado que carga el asset de texto y decide que contenido pintar.
class _CreditosPanelState extends State<CreditosPanel> {
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
  void didUpdateWidget(covariant CreditosPanel oldWidget) {
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
            borderRadius: BorderRadius.circular(ForRadius.contentPanel),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                ForColors.creditsGradientTop,
                ForColors.creditsGradientMid,
                ForColors.creditsGradientBottom,
              ],
            ),
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                widget.compact ? ForSpacing.md : ForSpacing.xl,
                widget.compact ? 44 : ForSizes.creditsPanelTopPadding,
                widget.compact ? ForSpacing.md : ForSpacing.xl,
                widget.compact ? 28 : ForSizes.creditsPanelBottomPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ForSizes.creditsPanelMaxWidth,
                  ),
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
                height: ForSizes.creditsFadeHeight,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(ForRadius.contentPanel),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      ForColors.creditsGradientTop,
                      ForColors.creditsTopFadeEnd,
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                height: ForSizes.creditsFadeHeight,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(ForRadius.contentPanel),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      ForColors.creditsBottomFadeStart,
                      ForColors.creditsGradientBottom,
                    ],
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
          padding: EdgeInsets.only(
            bottom: widget.compact ? ForSpacing.sm : ForSpacing.lg,
          ),
          child: _textoCredito(linea.texto!, style: _heroStyle),
        );
      case _TipoLineaCredito.subtitle:
        return Padding(
          padding: EdgeInsets.only(
            bottom: widget.compact
                ? ForSpacing.md
                : ForSizes.creditsSubtitleBottomPadding,
          ),
          child: _textoCredito(linea.texto!, style: _subtitleStyle),
        );
      case _TipoLineaCredito.section:
        return Padding(
          padding: EdgeInsets.only(
            top: widget.compact ? ForSpacing.xs : ForSpacing.sm,
            bottom: ForSpacing.creditsSpacer,
          ),
          child: _textoCredito(linea.texto!, style: _sectionStyle),
        );
      case _TipoLineaCredito.entry:
        return Padding(
          padding: EdgeInsets.only(
            bottom: widget.compact ? ForSpacing.md : ForSpacing.lg,
          ),
          child: Column(
            children: [
              _textoCredito(linea.etiqueta!, style: _entryLabelStyle),
              const SizedBox(height: ForSpacing.xs),
              _textoCredito(linea.texto!, style: _entryBodyStyle),
            ],
          ),
        );
      case _TipoLineaCredito.paragraph:
        return Padding(
          padding: EdgeInsets.only(
            bottom: widget.compact ? ForSpacing.md : ForSpacing.lg,
          ),
          child: _textoCredito(linea.texto!, style: _paragraphStyle),
        );
      case _TipoLineaCredito.spacer:
        return const SizedBox(height: ForSpacing.creditsSpacer);
    }
  }

  Widget _textoCredito(String texto, {required TextStyle style}) {
    return Text(
      texto,
      textAlign: widget.compact ? TextAlign.start : TextAlign.center,
      softWrap: true,
      textWidthBasis: TextWidthBasis.parent,
      style: style,
    );
  }

  TextStyle get _heroStyle => widget.compact
      ? ForTypography.creditsHero.copyWith(fontSize: 18, letterSpacing: 0)
      : ForTypography.creditsHero;

  TextStyle get _subtitleStyle => widget.compact
      ? ForTypography.creditsSubtitle.copyWith(fontSize: 14, letterSpacing: 0)
      : ForTypography.creditsSubtitle;

  TextStyle get _sectionStyle => widget.compact
      ? ForTypography.creditsSection.copyWith(fontSize: 14, letterSpacing: 0)
      : ForTypography.creditsSection;

  TextStyle get _entryLabelStyle => widget.compact
      ? ForTypography.creditsEntryLabel.copyWith(fontSize: 11, letterSpacing: 0)
      : ForTypography.creditsEntryLabel;

  TextStyle get _entryBodyStyle => widget.compact
      ? ForTypography.creditsEntryBody.copyWith(fontSize: 13, height: 1.35)
      : ForTypography.creditsEntryBody;

  TextStyle get _paragraphStyle => widget.compact
      ? ForTypography.creditsParagraph.copyWith(fontSize: 13, height: 1.45)
      : ForTypography.creditsParagraph;
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

/// Tipos de linea que puede generar el parser del texto de creditos.
enum _TipoLineaCredito { hero, subtitle, section, entry, paragraph, spacer }

/// Linea ya interpretada del archivo de creditos.
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
