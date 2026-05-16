import '../../domain/foundations_of_rome/foundations_of_rome.dart';

class LocalPlayerConfig {
  const LocalPlayerConfig({required this.kind});

  final TipoJugador kind;

  bool get isBot => kind == TipoJugador.bot;

  bool get isHuman => kind == TipoJugador.human;

  LocalPlayerConfig copyWith({TipoJugador? kind}) {
    return LocalPlayerConfig(kind: kind ?? this.kind);
  }
}

class LocalGameConfiguration {
  LocalGameConfiguration({required List<LocalPlayerConfig> players})
    : assert(players.length >= 2 && players.length <= 5),
      players = List<LocalPlayerConfig>.unmodifiable(players);

  factory LocalGameConfiguration.withKinds(List<TipoJugador> playerKinds) {
    return LocalGameConfiguration(
      players: playerKinds
          .map((TipoJugador kind) => LocalPlayerConfig(kind: kind))
          .toList(growable: false),
    );
  }

  factory LocalGameConfiguration.humans(int playerCount) {
    return LocalGameConfiguration.withKinds(
      List<TipoJugador>.filled(playerCount, TipoJugador.human),
    );
  }

  final List<LocalPlayerConfig> players;

  int get playerCount => players.length;

  int get humanCount =>
      players.where((LocalPlayerConfig player) => player.isHuman).length;

  List<TipoJugador> get playerKinds => players
      .map((LocalPlayerConfig player) => player.kind)
      .toList(growable: false);
}
