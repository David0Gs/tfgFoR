// Pieza visual pequena para mostrar una estadistica con etiqueta y valor.

import 'package:flutter/material.dart';

import '../for_theme.dart';

/// Muestra una estadistica individual dentro de tarjetas o dialogos.
///
/// En modo compacto reduce tipografia para encajar en el HUD movil.
class PlayerStat extends StatelessWidget {
  const PlayerStat({
    required this.label,
    required this.value,
    this.compact = false,
    super.key,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = compact
        ? ForTypography.playerStatLabel.copyWith(fontSize: 9)
        : ForTypography.playerStatLabel;
    final TextStyle valueStyle = compact
        ? ForTypography.playerStatValue.copyWith(fontSize: 9)
        : ForTypography.playerStatValue;

    return RichText(
      text: TextSpan(
        style: ForTypography.smallButton,
        children: [
          TextSpan(text: '$label: ', style: labelStyle),
          TextSpan(text: value, style: valueStyle),
        ],
      ),
    );
  }
}
