// Accion concreta que un bot ha decidido ejecutar. Encapsula los datos
// necesarios para aplicar la decision sobre el motor de juego.

import 'package:for_core/core.dart';
import 'bot_action_type.dart';

/// Representa una accion planificada por la inteligencia local de bots.
class BotPlannedAction {
  const BotPlannedAction._({
    required this.type,
    this.originCoord,
    this.building,
    this.rotationIndex,
    this.buildingIndex,
    this.fromMonument = false,
    this.marketIndex,
  });

  /// Crea una accion de construccion.
  const BotPlannedAction.build({
    required String originCoord,
    required Edificio building,
    required int rotationIndex,
    required int buildingIndex,
    required bool fromMonument,
  }) : this._(
         type: BotActionType.build,
         originCoord: originCoord,
         building: building,
         rotationIndex: rotationIndex,
         buildingIndex: buildingIndex,
         fromMonument: fromMonument,
       );

  /// Crea una accion de compra de parcela desde el mercado.
  const BotPlannedAction.buyDeed({required int marketIndex})
    : this._(type: BotActionType.buyDeed, marketIndex: marketIndex);

  /// Crea una accion de ingresos cuando no hay una jugada mejor disponible.
  const BotPlannedAction.income() : this._(type: BotActionType.income);

  final BotActionType type;
  final String? originCoord;
  final Edificio? building;
  final int? rotationIndex;
  final int? buildingIndex;
  final bool fromMonument;
  final int? marketIndex;

  /// Aplica la accion planificada sobre la partida indicada.
  void apply(Juego game) {
    switch (type) {
      case BotActionType.build:
        game.construir(
          originCoord!,
          building!,
          rotationIndex!,
          buildingIndex!,
          fromMonument,
        );
        break;
      case BotActionType.buyDeed:
        game.comprarParcela(marketIndex!);
        break;
      case BotActionType.income:
        game.accionIngresos();
        break;
    }
  }
}
