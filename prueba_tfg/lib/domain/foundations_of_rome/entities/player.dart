import '../building_catalog.dart';
import '../value_objects/player_kind.dart';
import 'building.dart';

class Jugador {
  final int id;
  String name;
  int coins;
  TipoJugador kind;
  int glory = 0;
  int populationTrack = 0;

  // Lógica de marcadores
  int availableMarkers = 8;
  final Set<String> lots = {}; // Parcelas donde tienes marcador o edificio

  // Bandeja de edificios disponibles
  final List<Edificio> availableBuildings = [];

  Jugador(this.id, this.name, this.coins, {this.kind = TipoJugador.human});

  bool get isBot => kind == TipoJugador.bot;

  bool get isHuman => kind == TipoJugador.human;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'coins': coins,
    'tipo': kind.name,
    'glory': glory,
    'marcadorPoblacion': populationTrack,
    'marcadoresDisponibles': availableMarkers,
    'parcelas': lots.toList(),
    'edificiosDisponibles': availableBuildings.map((b) => b.id).toList(),
  };

  factory Jugador.fromJson(Map<String, dynamic> json) {
    final String? serializedKind = json['tipo'] as String?;
    final TipoJugador kind = TipoJugador.values.firstWhere(
      (TipoJugador value) => value.name == serializedKind,
      orElse: () => TipoJugador.human,
    );
    Jugador p = Jugador(json['id'], json['name'], json['coins'], kind: kind);
    p.glory = json['glory'];
    p.populationTrack = json['marcadorPoblacion'];
    p.availableMarkers = json['marcadoresDisponibles'];
    p.lots.addAll((json['parcelas'] as List).cast<String>());
    // Reconstruir edificiosDisponibles estrictamente desde ids
    List<String> buildingRefs = (json['edificiosDisponibles'] as List)
        .cast<String>();
    for (String ref in buildingRefs) {
      final Edificio? template = buscarEdificioPorId(ref);
      if (template == null) {
        continue;
      }
      p.availableBuildings.add(template);
    }
    return p;
  }
}
