import '../../domain/foundations_of_rome/foundations_of_rome.dart';
import 'bot_action_type.dart';

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

  const BotPlannedAction.buyDeed({required int marketIndex})
    : this._(type: BotActionType.buyDeed, marketIndex: marketIndex);

  const BotPlannedAction.income() : this._(type: BotActionType.income);

  final BotActionType type;
  final String? originCoord;
  final Edificio? building;
  final int? rotationIndex;
  final int? buildingIndex;
  final bool fromMonument;
  final int? marketIndex;

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
