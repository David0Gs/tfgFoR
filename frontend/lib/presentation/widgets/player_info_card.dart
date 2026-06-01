// Tarjeta de informacion de jugador. Resume recursos, estado y puntuaciones
// principales de una plaza de la partida.

import 'package:flutter/material.dart';

import 'package:for_core/core.dart';
import '../for_theme.dart';
import 'player_stat.dart';

/// Tarjeta de jugador con version completa para escritorio y compacta para movil.
class PlayerInfoCard extends StatelessWidget {
  const PlayerInfoCard({
    required this.player,
    required this.isActive,
    required this.color,
    required this.isConsultable,
    required this.onTap,
    this.compact = false,
    super.key,
  });

  final Jugador player;
  final bool isActive;
  final Color color;
  final bool isConsultable;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ForColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ForRadius.panel),
        onTap: isConsultable ? onTap : null,
        child: Container(
          width: compact ? 92 : ForSizes.playerPanelWidth,
          constraints: BoxConstraints(minHeight: compact ? 28 : 0),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? ForSpacing.xs : ForSpacing.md,
            vertical: compact ? 4 : ForSizes.playerCardVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: isActive ? ForColors.panelActive : ForColors.panelDark,
            borderRadius: BorderRadius.circular(ForRadius.panel),
            border: Border.all(
              color: isActive ? color : ForColors.borderMuted,
              width: isActive
                  ? ForSizes.playerActiveBorderWidth
                  : ForSizes.playerDefaultBorderWidth,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.30),
                      blurRadius: ForSizes.playerActiveShadowBlur,
                      spreadRadius: ForSizes.playerActiveShadowSpread,
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: ForTypography.playerName.copyWith(
                  color: color,
                  fontSize: compact ? 10 : null,
                ),
              ),
              if (isConsultable && !compact) ...[
                const SizedBox(height: ForSpacing.xs),
                const Text(
                  'Toca para ver estadisticas',
                  style: ForTypography.helper,
                ),
              ],
              if (isActive) ...[
                if (player.isBot && !compact) ...[
                  const SizedBox(height: ForSpacing.compactGap),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ForSpacing.sm,
                      vertical: ForSizes.playerBotBadgeVerticalPadding,
                    ),
                    decoration: BoxDecoration(
                      color: ForColors.borderSubtle,
                      borderRadius: BorderRadius.circular(ForRadius.pill),
                      border: Border.all(color: ForColors.borderMuted),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.smart_toy,
                          size: ForSizes.playerBotIconSize,
                          color: ForColors.textMuted,
                        ),
                        SizedBox(width: ForSpacing.xs),
                        Text('Bot', style: ForTypography.badge),
                      ],
                    ),
                  ),
                  const SizedBox(height: ForSpacing.compactGap),
                  const Text(
                    'Turno automatico en partidas locales',
                    style: ForTypography.helper,
                  ),
                ],
                SizedBox(height: compact ? ForSpacing.xs : ForSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlayerStat(
                      label: 'Monedas',
                      value: '${player.coins}',
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 2 : ForSpacing.xs),
                    PlayerStat(
                      label: 'PV',
                      value: '${player.glory}',
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 2 : ForSpacing.xs),
                    PlayerStat(
                      label: 'Población',
                      value: '${player.populationTrack}',
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 2 : ForSpacing.xs),
                    PlayerStat(
                      label: 'Marcadores',
                      value: '${player.availableMarkers}/8',
                      compact: compact,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
