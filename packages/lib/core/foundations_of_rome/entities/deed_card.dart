// Entidad de carta de escritura. Representa una parcela disponible en el
// mercado y la era a la que pertenece.

import '../value_objects/era.dart';

/// Carta de parcela que puede comprarse desde el mercado.
class CartaEscritura {
  final String coord;
  final Era era;
  CartaEscritura(this.coord, this.era);

  /// Serializa la carta para guardar una partida.
  Map<String, dynamic> toJson() => {'coordenada': coord, 'era': era.name};

  /// Reconstruye una carta de escritura desde JSON.
  factory CartaEscritura.fromJson(Map<String, dynamic> json) {
    Era era = Era.values.firstWhere((e) => e.name == json['era']);
    return CartaEscritura(json['coordenada'], era);
  }
}
