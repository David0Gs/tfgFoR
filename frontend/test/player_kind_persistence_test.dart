import 'package:flutter_test/flutter_test.dart';
import 'package:for_core/core.dart';

void main() {
  test('save and load preserve bot players', () {
    final Juego game = Juego(
      3,
      playerKinds: const <TipoJugador>[
        TipoJugador.human,
        TipoJugador.bot,
        TipoJugador.bot,
      ],
    );

    final Juego restored = Juego.fromJson(game.toJson());

    expect(restored.players.map((Jugador player) => player.kind).toList(), [
      TipoJugador.human,
      TipoJugador.bot,
      TipoJugador.bot,
    ]);
  });
}
