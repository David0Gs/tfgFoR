// Barra de ayuda durante la colocacion de edificios. Informa al jugador del
// edificio seleccionado, rotacion actual y acciones disponibles.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../for_theme.dart';

/// Mensaje flotante que guia al jugador durante una colocacion.
class PlacementHintBar extends StatelessWidget {
  const PlacementHintBar({
    required this.buildingName,
    required this.coord,
    required this.rotationIndex,
    required this.totalRotations,
    super.key,
  });

  final String buildingName;
  final String coord;
  final int rotationIndex;
  final int totalRotations;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ForSpacing.md,
          vertical: ForSpacing.messageGap,
        ),
        decoration: BoxDecoration(
          color: ForColors.panelDark,
          borderRadius: BorderRadius.circular(ForRadius.panel),
          border: Border.all(color: ForColors.gold, width: 1),
        ),
        child: Text(
          'Colocando $buildingName en $coord | Rotación: ${rotationIndex + 1}/$totalRotations | Rueda: cambiar rotación | Click: confirmar',
          style: ForTypography.panelBody,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
