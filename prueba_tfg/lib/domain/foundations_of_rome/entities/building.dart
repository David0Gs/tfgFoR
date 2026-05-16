import '../value_objects/building_type.dart';

class Edificio {
  final String id;
  final String name;
  final String description;
  final TipoEdificio type;
  final List<List<List<int>>> rotations;
  final List<String> rotationNames;

  Edificio({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.rotations,
    required this.rotationNames,
  });
}
