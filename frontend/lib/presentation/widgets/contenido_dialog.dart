// Dialogo modal reutilizable para mostrar textos cargados desde assets. Lo
// reutilizan agradecimientos e instrucciones compartiendo el mismo marco visual.

import 'package:flutter/material.dart';

import '../for_theme.dart';
import 'creditos_panel.dart';

typedef ContenidoDialogBuilder =
    Widget Function(BuildContext context, String texto, bool compact);

typedef ContenidoDialogActionsBuilder =
    List<Widget> Function(BuildContext context);

/// Ventana modal generica para textos de menu con acciones opcionales.
class ContenidoDialog extends StatelessWidget {
  const ContenidoDialog({
    required this.title,
    required this.assetPath,
    required this.contentBuilder,
    this.errorMessage = 'No se pudo cargar el contenido.',
    this.actionsBuilder,
    super.key,
  });

  final String title;
  final String assetPath;
  final String errorMessage;
  final ContenidoDialogBuilder contentBuilder;
  final ContenidoDialogActionsBuilder? actionsBuilder;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool compact = size.shortestSide < 500;
    final Future<String> contenidoFuture = DefaultAssetBundle.of(
      context,
    ).loadString(assetPath);

    return Dialog(
      backgroundColor: ForColors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact
            ? ForSpacing.sm
            : ForSizes.creditsDialogInsetHorizontal,
        vertical: compact ? ForSpacing.sm : ForSizes.creditsDialogInsetVertical,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ForSizes.creditsDialogMaxWidth,
          maxHeight:
              size.height *
              (compact ? 0.92 : ForSizes.creditsDialogMaxHeightFactor),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ForRadius.dialog),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                ForColors.dialogGradientTop,
                ForColors.dialogGradientMid,
                ForColors.dialogGradientBottom,
              ],
            ),
            border: Border.all(
              color: ForColors.dialogFrame,
              width: ForSizes.creditsDialogFrameWidth,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: ForColors.shadow,
                blurRadius: ForSizes.creditsShadowBlur,
                offset: Offset(0, ForSizes.creditsShadowOffsetY),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(ForSizes.creditsDialogInnerMargin),
            padding: EdgeInsets.fromLTRB(
              compact ? ForSpacing.md : ForSpacing.xl,
              compact ? ForSpacing.md : ForSizes.creditsDialogHeaderTopPadding,
              compact ? ForSpacing.md : ForSpacing.xl,
              compact
                  ? ForSpacing.md
                  : ForSizes.creditsDialogHeaderBottomPadding,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                ForRadius.dialog - ForSizes.creditsDialogInnerMargin,
              ),
              color: ForColors.panel,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: compact
                            ? ForTypography.dialogTitle.copyWith(fontSize: 20)
                            : ForTypography.dialogTitle,
                      ),
                    ),
                    const SizedBox(width: ForSpacing.md),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      style: ForButtonStyles.icon(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: ForSizes.contentDialogTitleGap),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: ForColors.panelDark,
                      borderRadius: BorderRadius.circular(
                        ForRadius.contentPanel,
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
                                  padding: EdgeInsets.all(
                                    ForSizes.creditsLoadingPadding,
                                  ),
                                  child: CircularProgressIndicator(
                                    color: ForColors.goldLight,
                                  ),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    ForSizes.creditsErrorPadding,
                                  ),
                                  child: Text(
                                    errorMessage,
                                    textAlign: TextAlign.center,
                                    style: ForTypography.alertTitle,
                                  ),
                                ),
                              );
                            }

                            return contentBuilder(
                              context,
                              snapshot.data!.trim(),
                              compact,
                            );
                          },
                    ),
                  ),
                ),
                if (actionsBuilder != null) ...[
                  const SizedBox(height: ForSpacing.dialogGap),
                  _ContenidoDialogActions(actions: actionsBuilder!(context)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Distribuye botones de accion en fila o en varias lineas si no hay ancho.
class _ContenidoDialogActions extends StatelessWidget {
  const _ContenidoDialogActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            spacing: ForSpacing.md,
            runSpacing: ForSpacing.sm,
            children: actions,
          );
        }

        return Row(
          children: [
            for (int index = 0; index < actions.length; index++) ...[
              if (index > 0) const SizedBox(width: ForSpacing.md),
              Expanded(child: actions[index]),
            ],
          ],
        );
      },
    );
  }
}

/// Ventana modal especializada para creditos y agradecimientos.
class CreditosDialog extends StatelessWidget {
  const CreditosDialog({required this.assetPath, super.key});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return ContenidoDialog(
      title: 'Agradecimientos, y créditos',
      assetPath: assetPath,
      errorMessage:
          'No se pudo cargar el contenido temporal de agradecimientos.',
      contentBuilder: (BuildContext context, String texto, bool compact) {
        return CreditosPanel(texto: texto, compact: compact);
      },
    );
  }
}
