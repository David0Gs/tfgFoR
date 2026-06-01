// Overlay para elegir anclaje de construccion. Aparece cuando un edificio puede
// colocarse en varias parcelas de la huella seleccionada.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../for_theme.dart';

/// Panel flotante que permite seleccionar la casilla de anclaje.
class SeleccionAnclajeOverlay extends StatelessWidget {
  const SeleccionAnclajeOverlay({
    required this.coordenadas,
    required this.onSeleccionar,
    required this.onCancelar,
    super.key,
  });

  final List<String> coordenadas;
  final ValueChanged<String> onSeleccionar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: Container(
        color: ForColors.overlay,
        child: Center(
          child: IntrinsicWidth(
            child: Container(
              padding: const EdgeInsets.all(ForSpacing.lg),
              decoration: BoxDecoration(
                color: ForColors.panelMuted,
                borderRadius: BorderRadius.circular(ForRadius.panel),
                border: Border.all(color: ForColors.gold),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Selecciona la parcela de origen',
                    style: ForTypography.panelTitle,
                  ),
                  const SizedBox(height: ForSpacing.md),
                  ...coordenadas.map((String coord) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: ForSpacing.sm),
                      child: Center(
                        child: Material(
                          color: ForColors.overlay,
                          borderRadius: BorderRadius.circular(
                            ForRadius.compactButton,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              ForRadius.compactButton,
                            ),
                            onTap: () => onSeleccionar(coord),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: ForSpacing.md,
                                vertical: ForSpacing.messageGap,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(coord, style: ForTypography.panelBody),
                                  const SizedBox(width: ForSpacing.xl),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: ForColors.gold,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: ForSpacing.sm),
                  Center(
                    child: OutlinedButton(
                      onPressed: onCancelar,
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
