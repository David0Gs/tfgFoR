import '../../domain/foundations_of_rome/foundations_of_rome.dart';

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

  int get sizeScore => targetCoords.length;

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
