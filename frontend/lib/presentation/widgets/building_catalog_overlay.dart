// Overlay del catalogo de edificios. Muestra edificios disponibles y permite
// elegir uno para iniciar el flujo de colocacion sobre el tablero.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:for_core/core.dart';
import '../for_theme.dart';
import 'miniatura_edificio_3d.dart';

/// Funcion que valida si un edificio puede colocarse antes de seleccionarlo.
typedef BuildingPlacementValidator =
    String? Function(Edificio building, {required bool isFromMonument});

/// Panel flotante con edificios disponibles, monumentos y validaciones.
class BuildingCatalogOverlay extends StatelessWidget {
  const BuildingCatalogOverlay({
    required this.playerBuildings,
    required this.monuments,
    required this.validatePlacement,
    required this.monumentRequirementSummary,
    required this.thumbnailForBuilding,
    required this.onSelect,
    required this.onDisabledTap,
    required this.onCancel,
    this.compact = false,
    super.key,
  });

  final List<Edificio> playerBuildings;
  final List<Edificio> monuments;
  final BuildingPlacementValidator validatePlacement;
  final String? Function(String buildingId) monumentRequirementSummary;
  final String Function(Edificio building) thumbnailForBuilding;
  final void Function(Edificio building, {required bool fromMonument}) onSelect;
  final ValueChanged<String> onDisabledTap;
  final VoidCallback onCancel;
  final bool compact;

  int get _itemCount {
    return 2 +
        (playerBuildings.isEmpty ? 1 : playerBuildings.length) +
        (monuments.isEmpty ? 1 : monuments.length);
  }

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: Container(
        color: ForColors.overlay,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final EdgeInsets panelMargin = EdgeInsets.symmetric(
              horizontal: compact ? 14 : ForSpacing.xl,
              vertical: compact ? 20 : ForSpacing.xl,
            );
            final double availableWidth =
                constraints.maxWidth - panelMargin.horizontal;
            final double availableHeight =
                constraints.maxHeight - panelMargin.vertical;

            return Center(
              child: Padding(
                padding: panelMargin,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: availableWidth
                        .clamp(0, ForSizes.catalogWidth)
                        .toDouble(),
                    maxHeight: availableHeight
                        .clamp(0, constraints.maxHeight)
                        .toDouble(),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(
                      compact ? ForSpacing.sm : ForSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: ForColors.panelMuted,
                      borderRadius: BorderRadius.circular(ForRadius.panel),
                      border: Border.all(color: ForColors.gold),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Construir edificio',
                          style: compact
                              ? ForTypography.panelTitle.copyWith(fontSize: 14)
                              : ForTypography.panelTitle,
                        ),
                        SizedBox(
                          height: compact ? ForSpacing.xs : ForSpacing.md,
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            cacheExtent: 80,
                            itemCount: _itemCount,
                            itemBuilder: _buildListItem,
                          ),
                        ),
                        SizedBox(
                          height: compact ? ForSpacing.xs : ForSpacing.md,
                        ),
                        OutlinedButton(
                          onPressed: onCancel,
                          child: const Text('Cancelar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildListItem(BuildContext context, int index) {
    int cursor = 0;

    if (index == cursor) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: ForSpacing.compactGap),
        child: Text('Tus edificios', style: ForTypography.sectionTitle),
      );
    }
    cursor++;

    if (playerBuildings.isEmpty) {
      if (index == cursor) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: ForSpacing.sm),
          child: Text(
            'No hay edificios disponibles.',
            style: ForTypography.bodyMuted,
          ),
        );
      }
      cursor++;
    } else {
      final int localBuildingIndex = index - cursor;
      if (localBuildingIndex >= 0 &&
          localBuildingIndex < playerBuildings.length) {
        final Edificio building = playerBuildings[localBuildingIndex];
        final String? cannotPlaceReason = validatePlacement(
          building,
          isFromMonument: false,
        );

        return _CatalogEntry(
          building: building,
          thumbnailPath: thumbnailForBuilding(building),
          requirementText: null,
          backgroundColor: ForColors.overlay,
          trailingIcon: Icons.chevron_right,
          trailingColor: ForColors.gold,
          enabled: cannotPlaceReason == null,
          disabledReason: cannotPlaceReason,
          onTap: () => onSelect(building, fromMonument: false),
          onDisabledTap: onDisabledTap,
          compact: compact,
        );
      }
      cursor += playerBuildings.length;
    }

    if (index == cursor) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: ForColors.borderMuted, height: ForSpacing.dialogGap),
          Padding(
            padding: EdgeInsets.symmetric(vertical: ForSpacing.compactGap),
            child: Text('Monumentos', style: ForTypography.sectionTitle),
          ),
        ],
      );
    }
    cursor++;

    if (monuments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: ForSpacing.sm),
        child: Text(
          'No hay monumentos disponibles.',
          style: ForTypography.bodyMuted,
        ),
      );
    }

    final int monumentIndex = index - cursor;
    final Edificio building = monuments[monumentIndex];
    final String? cannotPlaceReason = validatePlacement(
      building,
      isFromMonument: true,
    );

    return _CatalogEntry(
      building: building,
      thumbnailPath: thumbnailForBuilding(building),
      requirementText: monumentRequirementSummary(building.id),
      backgroundColor: ForColors.infoOverlay,
      trailingIcon: Icons.chevron_right,
      trailingColor: ForColors.infoLight,
      enabled: cannotPlaceReason == null,
      disabledReason: cannotPlaceReason,
      onTap: () => onSelect(building, fromMonument: true),
      onDisabledTap: onDisabledTap,
      compact: compact,
    );
  }
}

/// Fila visual de un edificio dentro del catalogo.
class _CatalogEntry extends StatelessWidget {
  const _CatalogEntry({
    required this.building,
    required this.thumbnailPath,
    required this.requirementText,
    required this.backgroundColor,
    required this.trailingIcon,
    required this.trailingColor,
    required this.enabled,
    required this.disabledReason,
    required this.onTap,
    required this.onDisabledTap,
    required this.compact,
  });

  final Edificio building;
  final String thumbnailPath;
  final String? requirementText;
  final Color backgroundColor;
  final IconData trailingIcon;
  final Color trailingColor;
  final bool enabled;
  final String? disabledReason;
  final VoidCallback onTap;
  final ValueChanged<String> onDisabledTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double thumbnailWidth = compact ? 72 : ForSizes.thumbnailWidth;
    final double thumbnailHeight = compact ? 40 : ForSizes.thumbnailHeight;
    final double entryPadding = compact
        ? ForSpacing.compactGap
        : ForSpacing.messageGap;
    final double gap = compact ? ForSpacing.sm : ForSpacing.md;
    final TextStyle titleStyle = enabled
        ? ForTypography.catalogEntryTitle
        : ForTypography.catalogEntryTitleDisabled;
    final TextStyle bodyStyle = enabled
        ? ForTypography.catalogEntryBody
        : ForTypography.catalogEntryBodyDisabled;
    final String? placementStateText = !enabled && disabledReason != null
        ? (disabledReason == 'Selecciona una parcela primero'
              ? 'Estado: selecciona una parcela para validar colocacion.'
              : 'Estado: no colocable ahora. $disabledReason')
        : null;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 5 : ForSpacing.sm),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(ForRadius.compactButton),
          child: InkWell(
            borderRadius: BorderRadius.circular(ForRadius.compactButton),
            onTap: enabled
                ? onTap
                : () {
                    onDisabledTap(
                      disabledReason ?? 'No puedes colocar este edificio aquí.',
                    );
                  },
            child: Padding(
              padding: EdgeInsets.all(entryPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: thumbnailWidth,
                    height: thumbnailHeight,
                    child: RepaintBoundary(
                      child: MiniaturaEdificio3D(videoPath: thumbnailPath),
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${building.name} (${_nombreTipoEdificio(building.type)})',
                          style: compact
                              ? titleStyle.copyWith(fontSize: 11)
                              : titleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: compact ? 2 : ForSpacing.xs),
                        Text(
                          building.description,
                          style: compact
                              ? bodyStyle.copyWith(fontSize: 10)
                              : bodyStyle,
                          maxLines: compact ? 1 : 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (requirementText != null) ...[
                          SizedBox(height: compact ? 2 : ForSpacing.xs),
                          Text(
                            requirementText!,
                            style: compact
                                ? bodyStyle.copyWith(
                                    color: enabled ? ForColors.goldLight : null,
                                    fontSize: 10,
                                  )
                                : enabled
                                ? ForTypography.catalogEntryBody.copyWith(
                                    color: ForColors.goldLight,
                                  )
                                : ForTypography.catalogEntryBodyDisabled,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (placementStateText != null) ...[
                          SizedBox(height: compact ? 2 : ForSpacing.xs),
                          Text(
                            placementStateText,
                            style: compact
                                ? ForTypography.catalogEntryBodyDisabled
                                      .copyWith(fontSize: 10)
                                : ForTypography.catalogEntryBodyDisabled,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: ForSpacing.sm),
                  Icon(
                    trailingIcon,
                    color: trailingColor,
                    size: compact ? 18 : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _nombreTipoEdificio(TipoEdificio type) {
  switch (type) {
    case TipoEdificio.residential:
      return 'Residencial';
    case TipoEdificio.commercial:
      return 'Comercial';
    case TipoEdificio.civic:
      return 'Cívico';
  }
}
