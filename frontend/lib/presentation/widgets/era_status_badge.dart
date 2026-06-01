// Indicador de era y sala remota del tablero. Resume el progreso de partida en
// una pieza compacta de interfaz.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../for_theme.dart';

/// Badge flotante con informacion de era, ronda y sala.
class EraStatusBadge extends StatelessWidget {
  const EraStatusBadge({
    required this.eraName,
    required this.remainingCards,
    this.roomAlias,
    this.compact = false,
    super.key,
  });

  final String eraName;
  final int remainingCards;
  final String? roomAlias;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? ForSpacing.sm : ForSpacing.lg,
          vertical: compact ? ForSpacing.xs : ForSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: ForColors.panelDark,
          borderRadius: BorderRadius.circular(ForRadius.panel),
          border: Border.all(color: ForColors.gold, width: 1),
        ),
        child: Text(
          '${_roomPrefix()}ERA $eraName • Cartas restantes: $remainingCards',
          style: compact
              ? ForTypography.eraBadge.copyWith(fontSize: 10)
              : ForTypography.eraBadge,
        ),
      ),
    );
  }

  String _roomPrefix() {
    final String alias = roomAlias?.trim() ?? '';
    if (alias.isEmpty) {
      return '';
    }
    return 'SALA $alias • ';
  }
}
