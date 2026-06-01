// Entidad de propiedad construida. Une una plantilla de edificio con su dueño,
// rotacion y casillas ocupadas en el tablero.

import '../building_catalog.dart';
import '../value_objects/building_type.dart';
import 'building.dart';

/// Edificio ya colocado en el tablero.
class Propiedad {
  final int ownerId;
  final Edificio template; // Referencia al plano.
  final int rotationIndex; // Indice de rotacion aplicada.
  final List<String> occupiedCoords;

  Propiedad({
    required this.ownerId,
    required this.template,
    required this.rotationIndex,
    required this.occupiedCoords,
  });

  /// Acceso directo al tipo del edificio base.
  TipoEdificio get type => template.type;

  /// Serializa la propiedad para guardar o enviar una partida.
  Map<String, dynamic> toJson() => {
    'idPropietario': ownerId,
    'idPlantilla': template.id,
    'indiceRotacion': rotationIndex,
    'coordenadasOcupadas': occupiedCoords,
  };

  /// Reconstruye una propiedad desde JSON resolviendo su plantilla por id.
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
