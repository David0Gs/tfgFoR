// Boton iconografico reutilizable de toolbar. Centraliza tamaño, estilo,
// tooltip y estado deshabilitado.

import 'package:flutter/material.dart';

import '../for_theme.dart';

/// Boton cuadrado usado por las barras de herramientas del tablero.
class ToolbarIconButton extends StatelessWidget {
  const ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = ForSizes.toolbarButtonHeight,
    this.iconSize = ForSizes.icon,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ForButtonStyles.toolbar().copyWith(
            padding: WidgetStateProperty.all(EdgeInsets.zero),
          ),
          child: Icon(icon, size: iconSize),
        ),
      ),
    );
  }
}
