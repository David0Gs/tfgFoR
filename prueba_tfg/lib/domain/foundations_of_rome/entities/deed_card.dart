import '../value_objects/era.dart';

class CartaEscritura {
  final String coord;
  final Era era;
  CartaEscritura(this.coord, this.era);

  Map<String, dynamic> toJson() => {'coordenada': coord, 'era': era.name};

  factory CartaEscritura.fromJson(Map<String, dynamic> json) {
    Era era = Era.values.firstWhere((e) => e.name == json['era']);
    return CartaEscritura(json['coordenada'], era);
  }
}
