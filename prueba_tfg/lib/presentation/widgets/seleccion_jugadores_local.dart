import 'package:flutter/material.dart';

import '../../application/local_game/local_game.dart';
import '../../domain/foundations_of_rome/foundations_of_rome.dart';
import '../for_theme.dart';

const List<int> _playerCountOptions = <int>[2, 3, 4, 5];

String boardModelPathForPlayerCount(int playerCount) {
  switch (playerCount) {
    case 2:
      return 'assets/models/tablero7.glb';
    case 3:
      return 'assets/models/tablero8.glb';
    case 4:
      return 'assets/models/tablero9.glb';
    case 5:
      return 'assets/models/tablero10.glb';
  }

  throw ArgumentError.value(
    playerCount,
    'playerCount',
    'Solo se admiten partidas de 2 a 5 jugadores.',
  );
}

String _etiquetaTipoJugador(TipoJugador kind) {
  switch (kind) {
    case TipoJugador.human:
      return 'Humano';
    case TipoJugador.bot:
      return 'Bot';
  }
}

Future<LocalGameConfiguration?> mostrarSeleccionJugadoresLocal(
  BuildContext context,
) {
  int playerCount = 2;
  List<TipoJugador> playerKinds = List<TipoJugador>.filled(
    playerCount,
    TipoJugador.human,
  );
  String? validationError;

  void resizePlayerKinds(int nextPlayerCount) {
    if (nextPlayerCount > playerKinds.length) {
      playerKinds = List<TipoJugador>.from(playerKinds)
        ..addAll(
          List<TipoJugador>.filled(
            nextPlayerCount - playerKinds.length,
            TipoJugador.human,
          ),
        );
      return;
    }

    playerKinds = playerKinds.take(nextPlayerCount).toList(growable: true);
  }

  return showDialog<LocalGameConfiguration>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: const Text('Jugadores en partida local'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: playerCount,
                      decoration: const InputDecoration(
                        labelText: 'Numero de jugadores',
                      ),
                      items: _playerCountOptions
                          .map(
                            (int option) => DropdownMenuItem<int>(
                              value: option,
                              child: Text('$option jugadores'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (int? value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          playerCount = value;
                          resizePlayerKinds(playerCount);
                          validationError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Configura cada plaza como humano o bot.'),
                    const SizedBox(height: 12),
                    ...List<Widget>.generate(playerCount, (int index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(child: Text('Plaza ${index + 1}')),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 160,
                              child: DropdownButtonFormField<TipoJugador>(
                                initialValue: playerKinds[index],
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: TipoJugador.values
                                    .map(
                                      (TipoJugador kind) =>
                                          DropdownMenuItem<TipoJugador>(
                                            value: kind,
                                            child: Text(
                                              _etiquetaTipoJugador(kind),
                                            ),
                                          ),
                                    )
                                    .toList(growable: false),
                                onChanged: (TipoJugador? value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    playerKinds[index] = value;
                                    validationError = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (validationError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          validationError!,
                          style: ForTypography.smallButton.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final LocalGameConfiguration configuration =
                      LocalGameConfiguration.withKinds(playerKinds);
                  if (configuration.humanCount == 0) {
                    setState(() {
                      validationError =
                          'La partida local debe tener al menos un jugador humano.';
                    });
                    return;
                  }

                  Navigator.of(dialogContext).pop(configuration);
                },
                child: const Text('Iniciar partida'),
              ),
            ],
          );
        },
      );
    },
  );
}
