// Barra del mercado de parcelas. Presenta solares disponibles, costes y estado
// de compra de cada posicion desde el HUD del tablero.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../for_theme.dart';

/// Muestra el mercado de escrituras/parcela del turno actual.
class DeedMarketBar extends StatelessWidget {
  const DeedMarketBar({
    required this.labels,
    required this.enabled,
    required this.onBuy,
    this.compact = false,
    super.key,
  });

  final List<String> labels;
  final bool enabled;
  final Future<void> Function(int index) onBuy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget panel = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? ForSpacing.xs : ForSpacing.messageGap,
        vertical: compact ? ForSpacing.xs : ForSpacing.compactGap,
      ),
      decoration: BoxDecoration(
        color: ForColors.overlay,
        borderRadius: BorderRadius.circular(ForRadius.panel),
        border: Border.all(color: ForColors.borderMuted),
      ),
      child: compact ? _buildCompactButtons() : _buildDesktopButtons(),
    );

    return PointerInterceptor(
      child: compact
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SizedBox(width: double.infinity, child: panel),
              ),
            )
          : panel,
    );
  }

  Widget _buildCompactButtons() {
    return Row(
      children: List.generate(labels.length, (int index) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: TextButton(
              onPressed: enabled ? () => onBuy(index) : null,
              style: ForButtonStyles.marketLot().copyWith(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                ),
                minimumSize: WidgetStateProperty.all(Size.zero),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                fixedSize: WidgetStateProperty.all(const Size.fromHeight(20)),
                textStyle: WidgetStateProperty.all(
                  ForTypography.smallButton.copyWith(fontSize: 12),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(labels[index]),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDesktopButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (int index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: ForSpacing.xs),
            child: TextButton(
              onPressed: enabled ? () => onBuy(index) : null,
              style: ForButtonStyles.marketLot(),
              child: Text(labels[index]),
            ),
          );
        }),
      ),
    );
  }
}
