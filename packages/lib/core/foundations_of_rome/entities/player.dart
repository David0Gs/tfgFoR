// Entidad de jugador del motor. Guarda recursos, solares, edificios
// disponibles y si la plaza la controla una persona o un bot.

import '../building_catalog.dart';
import '../value_objects/player_kind.dart';
import 'building.dart';

/// Estado de un jugador dentro de una partida.
class Jugador {
  final int id;
  String name;
  int coins;
  TipoJugador kind;
  int glory = 0;
  int populationTrack = 0;

  // Logica de marcadores.
  int availableMarkers = 8;
  final Set<String> lots = {}; // Parcelas donde tienes marcador o edificio

  // Bandeja de edificios disponibles.
  final List<Edificio> availableBuildings = [];

  Jugador(this.id, this.name, this.coins, {this.kind = TipoJugador.human});

  /// Indica si esta plaza esta controlada por un bot.
  bool get isBot => kind == TipoJugador.bot;

  /// Indica si esta plaza esta controlada por una persona.
  bool get isHuman => kind == TipoJugador.human;

  /// Serializa el jugador para guardar o enviar una partida.
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

  /// Reconstruye un jugador desde JSON.
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
    // Reconstruir edificiosDisponibles estrictamente desde ids.
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
