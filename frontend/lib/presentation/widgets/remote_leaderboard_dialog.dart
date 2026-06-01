// Dialogo del leaderboard remoto. Pinta estados de carga, error, lista vacia o
// ranking recibido desde el servidor.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:for_core/core.dart';
import '../for_theme.dart';

/// Modal que muestra la clasificacion global recibida del backend.
class RemoteLeaderboardDialog extends StatelessWidget {
  const RemoteLeaderboardDialog({
    required this.entries,
    required this.loading,
    required this.error,
    required this.onReload,
    super.key,
  });

  final List<EntradaClasificacion> entries;
  final bool loading;
  final String? error;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: AlertDialog(
        title: const Text('Leaderboard global'),
        content: _buildContent(),
        actions: [
          TextButton(onPressed: onReload, child: const Text('Recargar')),
          FilledButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (loading && entries.isEmpty) {
      return const SizedBox(
        height: ForSizes.leaderboardEmptyHeight,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: ForSpacing.md),
              Text('Cargando top 10 global...'),
            ],
          ),
        ),
      );
    }

    if (error != null && entries.isEmpty) {
      return SizedBox(
        height: ForSizes.leaderboardErrorHeight,
        child: Center(child: Text(error!, textAlign: TextAlign.center)),
      );
    }

    if (entries.isEmpty) {
      return const SizedBox(
        height: ForSizes.leaderboardEmptyHeight,
        child: Center(
          child: Text('Aun no hay puntuaciones globales registradas.'),
        ),
      );
    }

    return SizedBox(
      width: ForSizes.leaderboardWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) ...[
            Text(error!, style: ForTypography.errorBody),
            const SizedBox(height: ForSpacing.md),
          ],
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final EntradaClasificacion entry = entries[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(entry.alias),
                  trailing: Text('${entry.puntuacion} PV'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
