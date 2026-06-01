// Configuracion de una partida local. Define cuantas plazas habra y si cada
// una estara controlada por una persona o por un bot.

import 'package:for_core/core.dart';

/// Configuracion de una plaza concreta dentro de una partida local.
class LocalPlayerConfig {
  const LocalPlayerConfig({required this.kind});

  final TipoJugador kind;

  /// Indica si esta plaza sera controlada automaticamente por un bot.
  bool get isBot => kind == TipoJugador.bot;

  /// Indica si esta plaza sera controlada manualmente por una persona.
  bool get isHuman => kind == TipoJugador.human;

  /// Crea una copia cambiando solo los campos indicados.
  LocalPlayerConfig copyWith({TipoJugador? kind}) {
    return LocalPlayerConfig(kind: kind ?? this.kind);
  }
}

/// Configuracion completa usada al arrancar el tablero en modo local.
class LocalGameConfiguration {
  LocalGameConfiguration({required List<LocalPlayerConfig> players})
    : assert(players.length >= 2 && players.length <= 5),
      players = List<LocalPlayerConfig>.unmodifiable(players);

  /// Crea una configuracion a partir de una lista de tipos de jugador.
  factory LocalGameConfiguration.withKinds(List<TipoJugador> playerKinds) {
    return LocalGameConfiguration(
      players: playerKinds
          .map((TipoJugador kind) => LocalPlayerConfig(kind: kind))
          .toList(growable: false),
    );
  }

  /// Crea una configuracion local con todos los jugadores humanos.
  factory LocalGameConfiguration.humans(int playerCount) {
    return LocalGameConfiguration.withKinds(
      List<TipoJugador>.filled(playerCount, TipoJugador.human),
    );
  }

  final List<LocalPlayerConfig> players;

  /// Numero total de plazas de la partida.
  int get playerCount => players.length;

  /// Numero de plazas controladas por personas.
  int get humanCount =>
      players.where((LocalPlayerConfig player) => player.isHuman).length;

  /// Lista simple de tipos, util para crear el motor de juego.
  List<TipoJugador> get playerKinds => players
      .map((LocalPlayerConfig player) => player.kind)
      .toList(growable: false);
}
