// Dialogo con estadisticas detalladas de los jugadores. Permite consultar el
// estado completo de recursos y puntuacion durante la partida.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:for_core/core.dart';
import '../for_theme.dart';
import 'player_stat.dart';

/// Modal de estadisticas ampliadas de todos los jugadores.
class PlayerStatsDialog extends StatelessWidget {
  const PlayerStatsDialog({
    required this.player,
    required this.color,
    required this.builtBuildings,
    super.key,
  });

  final Jugador player;
  final Color color;
  final int builtBuildings;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: AlertDialog(
        backgroundColor: ForColors.panelMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ForRadius.panel),
          side: BorderSide(color: color, width: 1.2),
        ),
        title: Text(
          'Estadisticas de ${player.name}',
          style: ForTypography.panelTitle.copyWith(color: color),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlayerStat(label: 'Monedas', value: '${player.coins}'),
            const SizedBox(height: ForSpacing.compactGap),
            PlayerStat(label: 'PV', value: '${player.glory}'),
            const SizedBox(height: ForSpacing.compactGap),
            PlayerStat(label: 'Población', value: '${player.populationTrack}'),
            const SizedBox(height: ForSpacing.compactGap),
            PlayerStat(
              label: 'Marcadores',
              value: '${player.availableMarkers}/8',
            ),
            const SizedBox(height: ForSpacing.compactGap),
            PlayerStat(label: 'Parcelas', value: '${player.lots.length}'),
            const SizedBox(height: ForSpacing.compactGap),
            PlayerStat(label: 'Edificios', value: '$builtBuildings'),
            if (player.isBot) ...[
              const SizedBox(height: ForSpacing.md),
              const Text(
                'Jugador controlado por bot',
                style: ForTypography.helper,
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
