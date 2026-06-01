// Dialogo de resumen de era o final de partida. Presenta puntuaciones,
// beneficios y acciones para continuar o volver al menu.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../for_theme.dart';

/// Modal reutilizable para resumen de era y resumen final.
class ResumenPartidaDialog extends StatelessWidget {
  const ResumenPartidaDialog({
    required this.title,
    required this.lines,
    super.key,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: AlertDialog(
        backgroundColor: ForColors.panelMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ForRadius.panel),
        ),
        title: Text(title, style: ForTypography.panelTitle),
        content: SizedBox(
          width: ForSizes.catalogWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map(
                    (String line) => Padding(
                      padding: const EdgeInsets.only(bottom: ForSpacing.sm),
                      child: Text(line, style: ForTypography.alertBody),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
