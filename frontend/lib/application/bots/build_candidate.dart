// Candidato de construccion evaluado por el bot. Guarda edificio, rotacion y
// casillas afectadas para poder comparar distintas jugadas posibles.

import 'package:for_core/core.dart';

/// Posible construccion que el bot podria ejecutar en su turno.
class BuildCandidate {
  const BuildCandidate({
    required this.originCoord,
    required this.building,
    required this.rotationIndex,
    required this.buildingIndex,
    required this.targetCoords,
  });

  final String originCoord;
  final Edificio building;
  final int rotationIndex;
  final int buildingIndex;
  final List<String> targetCoords;

  /// Puntuacion basica por tamaño: cuantos mas solares ocupa, mejor.
  int get sizeScore => targetCoords.length;

  /// Prioridad simple por tipo de edificio cuando hay empate por tamaño.
  int get typePriority {
    switch (building.type) {
      case TipoEdificio.residential:
        return 3;
      case TipoEdificio.commercial:
        return 2;
      case TipoEdificio.civic:
        return 1;
    }
  }

  /// Compara candidatos para elegir la mejor construccion disponible.
  int compareTo(BuildCandidate other) {
    final int bySize = sizeScore.compareTo(other.sizeScore);
    if (bySize != 0) {
      return bySize;
    }

    final int byType = typePriority.compareTo(other.typePriority);
    if (byType != 0) {
      return byType;
    }

    final int byOrigin = other.originCoord.compareTo(originCoord);
    if (byOrigin != 0) {
      return byOrigin;
    }

    return other.building.id.compareTo(building.id);
  }
}
