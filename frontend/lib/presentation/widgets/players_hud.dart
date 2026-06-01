// HUD de jugadores. Muestra tarjetas de jugador y destaca el turno actual
// dentro del tablero en disposicion de escritorio o movil.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:for_core/core.dart';
import '../for_theme.dart';
import 'player_info_card.dart';

/// Panel de jugadores visible sobre el tablero.
class PlayersHud extends StatelessWidget {
  const PlayersHud({
    required this.players,
    required this.currentPlayerId,
    required this.colorForPlayer,
    required this.isConsultable,
    required this.onPlayerTap,
    this.compact = false,
    super.key,
  });

  final List<Jugador> players;
  final int currentPlayerId;
  final Color Function(int playerId) colorForPlayer;
  final bool Function(Jugador player) isConsultable;
  final ValueChanged<Jugador> onPlayerTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: compact ? _buildCompactHud() : _buildDesktopHud(),
    );
  }

  Widget _buildDesktopHud() {
    return SizedBox(
      width: ForSizes.playersHudWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: players
            .map(
              (Jugador player) => Padding(
                padding: const EdgeInsets.only(bottom: ForSpacing.toolbarGap),
                child: PlayerInfoCard(
                  player: player,
                  isActive: player.id == currentPlayerId,
                  color: colorForPlayer(player.id),
                  isConsultable: isConsultable(player),
                  onTap: () => onPlayerTap(player),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCompactHud() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: players
          .map(
            (Jugador player) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: PlayerInfoCard(
                player: player,
                isActive: player.id == currentPlayerId,
                color: colorForPlayer(player.id),
                isConsultable: isConsultable(player),
                onTap: () => onPlayerTap(player),
                compact: true,
              ),
            ),
          )
          .toList(),
    );
  }
}
