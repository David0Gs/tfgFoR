import '../building_catalog.dart';
import '../value_objects/building_type.dart';
import 'building.dart';

class Propiedad {
  final int ownerId;
  final Edificio template; // Referencia al plano
  final int rotationIndex; // Índice de rotación aplicada
  final List<String> occupiedCoords;

  Propiedad({
    required this.ownerId,
    required this.template,
    required this.rotationIndex,
    required this.occupiedCoords,
  });

  // Acceso directo a propiedades del template para comodidad
  TipoEdificio get type => template.type;

  Map<String, dynamic> toJson() => {
    'idPropietario': ownerId,
    'idPlantilla': template.id,
    'indiceRotacion': rotationIndex,
    'coordenadasOcupadas': occupiedCoords,
  };

  factory Propiedad.fromJson(Map<String, dynamic> json) {
    final String templateRef = json['idPlantilla'] as String;
    final Edificio? template = buscarEdificioPorId(templateRef);
    if (template == null) {
      throw StateError('No se encuentra Edificio con id "$templateRef"');
    }
    return Propiedad(
      ownerId: json['idPropietario'],
      template: template,
      rotationIndex: json['indiceRotacion'],
      occupiedCoords: (json['coordenadasOcupadas'] as List).cast<String>(),
    );
  }
}
