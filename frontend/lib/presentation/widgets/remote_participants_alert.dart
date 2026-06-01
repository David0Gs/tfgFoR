// Aviso de participantes remotos desconectados. Se muestra sobre el tablero
// cuando falta algun jugador en una sala online.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../for_theme.dart';

/// Alerta flotante para incidencias de presencia en modo remoto.
class RemoteParticipantsAlert extends StatelessWidget {
  const RemoteParticipantsAlert({required this.message, super.key});

  final String message;

  bool get _isFinalizada => message.toLowerCase().contains('finalizada');

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: Container(
        padding: const EdgeInsets.all(ForSpacing.lg),
        decoration: BoxDecoration(
          color: ForColors.dangerPanel,
          borderRadius: BorderRadius.circular(ForRadius.panel),
          border: Border.all(
            color: ForColors.dangerBorder,
            width: ForSizes.alertBorderWidth,
          ),
          boxShadow: const [
            BoxShadow(
              color: ForColors.shadow,
              blurRadius: ForSizes.alertShadowBlur,
              offset: Offset(0, ForSizes.alertShadowOffsetY),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: ForSizes.alertIconTopPadding),
              child: Icon(
                Icons.warning_amber_rounded,
                color: ForColors.goldPale,
                size: ForSizes.alertIconSize,
              ),
            ),
            const SizedBox(width: ForSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isFinalizada
                        ? 'Partida finalizada'
                        : 'Jugadores desconectados',
                    style: ForTypography.alertTitle,
                  ),
                  const SizedBox(height: ForSpacing.compactGap),
                  Text(message, style: ForTypography.alertBody),
                ],
              ),
            ),
            const SizedBox(width: ForSpacing.md),
          ],
        ),
      ),
    );
  }
}
