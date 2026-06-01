// Servicio de decision para bots locales. Recorre construcciones y compras
// posibles usando las reglas del motor y devuelve la accion mas razonable.

import 'package:for_core/core.dart';
import 'bot_planned_action.dart';
import 'build_candidate.dart';
import 'buy_candidate.dart';

/// Calcula la siguiente accion de un jugador bot en modo local.
class FoundationsOfRomeBotService {
  /// Decide la accion del bot para el estado actual de la partida.
  BotPlannedAction decide(Juego game) {
    final BuildCandidate? normalBuild = _findBestBuild(
      game,
      buildings: game.players[game.indiceJugadorActual].availableBuildings,
      fromMonument: false,
    );
    if (normalBuild != null) {
      return BotPlannedAction.build(
        originCoord: normalBuild.originCoord,
        building: normalBuild.building,
        rotationIndex: normalBuild.rotationIndex,
        buildingIndex: normalBuild.buildingIndex,
        fromMonument: false,
      );
    }

    final BuildCandidate? monumentBuild = _findBestBuild(
      game,
      buildings: game.monumentosDisponibles,
      fromMonument: true,
    );
    if (monumentBuild != null) {
      return BotPlannedAction.build(
        originCoord: monumentBuild.originCoord,
        building: monumentBuild.building,
        rotationIndex: monumentBuild.rotationIndex,
        buildingIndex: monumentBuild.buildingIndex,
        fromMonument: true,
      );
    }

    final BuyCandidate? purchase = _findBestPurchase(game);
    if (purchase != null) {
      return BotPlannedAction.buyDeed(marketIndex: purchase.marketIndex);
    }

    return const BotPlannedAction.income();
  }

  /// Busca la mejor construccion valida entre los edificios indicados.
  BuildCandidate? _findBestBuild(
    Juego game, {
    required List<Edificio> buildings,
    required bool fromMonument,
  }) {
    final Jugador player = game.players[game.indiceJugadorActual];
    if (player.lots.isEmpty || buildings.isEmpty) {
      return null;
    }

    final List<String> origins = player.lots.toList()..sort();
    BuildCandidate? bestCandidate;

    for (final String originCoord in origins) {
      for (
        int buildingIndex = 0;
        buildingIndex < buildings.length;
        buildingIndex++
      ) {
        final Edificio building = buildings[buildingIndex];
        for (
          int rotationIndex = 0;
          rotationIndex < building.rotations.length;
          rotationIndex++
        ) {
          try {
            game.validarConstruccion(
              originCoord,
              building,
              rotationIndex,
              buildingIndex,
              fromMonument,
            );
          } on RuleError {
            continue;
          }

          final List<String> targetCoords = _buildTargetCoords(
            game: game,
            originCoord: originCoord,
            building: building,
            rotationIndex: rotationIndex,
          );

          final BuildCandidate candidate = BuildCandidate(
            originCoord: originCoord,
            building: building,
            rotationIndex: rotationIndex,
            buildingIndex: buildingIndex,
            targetCoords: targetCoords,
          );

          if (bestCandidate == null || candidate.compareTo(bestCandidate) > 0) {
            bestCandidate = candidate;
          }
        }
      }
    }

    return bestCandidate;
  }

  /// Calcula las coordenadas que ocuparia un edificio con una rotacion.
  List<String> _buildTargetCoords({
    required Juego game,
    required String originCoord,
    required Edificio building,
    required int rotationIndex,
  }) {
    final List<List<int>> rotation = building.rotations[rotationIndex];
    final int baseColumn = originCoord.codeUnitAt(0) - 65;
    final int baseRow = int.parse(originCoord.substring(1));
    final List<String> coords = <String>[];

    for (final List<int> offset in rotation) {
      final int column = baseColumn + offset[0];
      final int row = baseRow + offset[1];
      if (column < 0 ||
          column >= game.tamanoTablero ||
          row < 1 ||
          row > game.tamanoTablero) {
        return const <String>[];
      }
      coords.add('${String.fromCharCode(65 + column)}$row');
    }

    return coords;
  }

  /// Busca la parcela de mercado mas interesante para comprar.
  BuyCandidate? _findBestPurchase(Juego game) {
    final Jugador player = game.players[game.indiceJugadorActual];
    if (player.availableMarkers <= 0) {
      return null;
    }

    BuyCandidate? bestCandidate;

    for (int index = 0; index < game.mercado.length; index++) {
      final int cost = costes[index];
      if (cost > player.coins) {
        continue;
      }

      final String coord = game.mercado[index].coord;
      final BuyCandidate candidate = BuyCandidate(
        marketIndex: index,
        cost: cost,
        adjacentToOwnedLot: _isAdjacentToOwnedLot(game, player, coord),
      );

      if (bestCandidate == null || candidate.compareTo(bestCandidate) > 0) {
        bestCandidate = candidate;
      }
    }

    return bestCandidate;
  }

  /// Indica si la coordenada esta junto a alguna parcela del jugador.
  bool _isAdjacentToOwnedLot(Juego game, Jugador player, String coord) {
    for (final String neighbor in _neighbors(coord)) {
      if (!game.isCoordOnBoard(neighbor)) {
        continue;
      }
      if (player.lots.contains(neighbor)) {
        return true;
      }
    }
    return false;
  }

  /// Devuelve las cuatro coordenadas ortogonales vecinas.
  List<String> _neighbors(String coord) {
    final int column = coord.codeUnitAt(0);
    final int row = int.parse(coord.substring(1));
    return <String>[
      '${String.fromCharCode(column)}${row - 1}',
      '${String.fromCharCode(column)}${row + 1}',
      '${String.fromCharCode(column - 1)}$row',
      '${String.fromCharCode(column + 1)}$row',
    ];
  }
}
