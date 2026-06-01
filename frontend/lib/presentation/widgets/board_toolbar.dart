// Barra flotante de herramientas del tablero. Agrupa acciones frecuentes como
// audio, camara, rotacion, ranking, ingresos, guardado y salida al menu.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../for_theme.dart';
import 'toolbar_icon_button.dart';

/// Toolbar flotante con acciones del tablero y bloqueo durante interacciones.
class BoardToolbar extends StatelessWidget {
  const BoardToolbar({
    required this.isMutedListenable,
    required this.remoteModeActive,
    required this.leaderboardEnabled,
    required this.incomeEnabled,
    required this.saveEnabled,
    required this.onToggleMuted,
    required this.onResetCamera,
    required this.onShowLeaderboard,
    required this.onIncome,
    required this.onSave,
    required this.onExit,
    this.compact = false,
    this.actionsLocked = false,
    this.rotationEnabled = false,
    this.onRotate,
    this.cancelPlacementEnabled = false,
    this.onCancelPlacement,
    super.key,
  });

  final ValueListenable<bool> isMutedListenable;
  final bool remoteModeActive;
  final bool leaderboardEnabled;
  final bool incomeEnabled;
  final bool saveEnabled;
  final Future<void> Function() onToggleMuted;
  final VoidCallback onResetCamera;
  final VoidCallback? onShowLeaderboard;
  final VoidCallback? onIncome;
  final VoidCallback? onSave;
  final VoidCallback onExit;
  final bool compact;
  final bool actionsLocked;
  final bool rotationEnabled;
  final VoidCallback? onRotate;
  final bool cancelPlacementEnabled;
  final VoidCallback? onCancelPlacement;

  @override
  Widget build(BuildContext context) {
    final double buttonSize = compact ? 34 : ForSizes.toolbarButtonHeight;
    final double iconSize = compact ? 21 : ForSizes.icon;
    final double gap = compact ? 3 : ForSpacing.toolbarGap;

    return PointerInterceptor(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: isMutedListenable,
            builder: (BuildContext context, bool isMuted, Widget? child) {
              return ToolbarIconButton(
                tooltip: isMuted ? 'Activar musica' : 'Silenciar musica',
                icon: isMuted ? Icons.volume_off : Icons.volume_up,
                onPressed: actionsLocked ? null : onToggleMuted,
                size: buttonSize,
                iconSize: iconSize,
              );
            },
          ),
          SizedBox(height: gap),
          ToolbarIconButton(
            tooltip: 'Centrar vista',
            icon: Icons.center_focus_strong,
            onPressed: actionsLocked ? null : onResetCamera,
            size: buttonSize,
            iconSize: iconSize,
          ),
          SizedBox(height: gap),
          if (onRotate != null) ...[
            ToolbarIconButton(
              tooltip: 'Rotar edificio',
              icon: Icons.rotate_90_degrees_cw,
              onPressed: rotationEnabled ? onRotate : null,
              size: buttonSize,
              iconSize: iconSize,
            ),
            SizedBox(height: gap),
          ],
          if (onCancelPlacement != null) ...[
            ToolbarIconButton(
              tooltip: 'Cancelar colocacion',
              icon: Icons.close,
              onPressed: cancelPlacementEnabled ? onCancelPlacement : null,
              size: buttonSize,
              iconSize: iconSize,
            ),
            SizedBox(height: gap),
          ],
          if (remoteModeActive) ...[
            ToolbarIconButton(
              tooltip: 'Leaderboard',
              icon: Icons.leaderboard,
              onPressed: !actionsLocked && leaderboardEnabled
                  ? onShowLeaderboard
                  : null,
              size: buttonSize,
              iconSize: iconSize,
            ),
            SizedBox(height: gap),
          ],
          ToolbarIconButton(
            tooltip: 'Cobrar',
            icon: Icons.attach_money,
            onPressed: !actionsLocked && incomeEnabled ? onIncome : null,
            size: buttonSize,
            iconSize: iconSize,
          ),
          SizedBox(height: gap),
          if (!remoteModeActive) ...[
            ToolbarIconButton(
              tooltip: 'Guardar',
              icon: Icons.save_alt,
              onPressed: !actionsLocked && saveEnabled ? onSave : null,
              size: buttonSize,
              iconSize: iconSize,
            ),
            SizedBox(height: gap),
          ],
          ToolbarIconButton(
            tooltip: 'Salir al menu',
            icon: Icons.logout,
            onPressed: actionsLocked ? null : onExit,
            size: buttonSize,
            iconSize: iconSize,
          ),
        ],
      ),
    );
  }
}
