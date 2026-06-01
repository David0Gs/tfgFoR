// Dialogo de configuracion para partidas locales. Permite elegir el numero de
// jugadores y definir si cada plaza sera controlada por una persona o por un
// bot antes de abrir el tablero.

import 'package:flutter/material.dart';
import '../../application/local_game/local_game.dart';
import 'package:for_core/core.dart';
import '../for_theme.dart';

/// Opciones soportadas por las reglas y por los modelos 3D de tablero.
const List<int> _playerCountOptions = <int>[2, 3, 4, 5];

/// Relaciona el numero de jugadores con el tablero 3D que debe cargarse.
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

/// Traduce el tipo de jugador de dominio a texto visible en el formulario.
String _etiquetaTipoJugador(TipoJugador kind) {
  switch (kind) {
    case TipoJugador.human:
      return 'Humano';
    case TipoJugador.bot:
      return 'Bot';
  }
}

/// Muestra el dialogo y devuelve la configuracion elegida.
///
/// Si el usuario cancela, devuelve null para que el flujo de inicio no
/// continue.
Future<LocalGameConfiguration?> mostrarSeleccionJugadoresLocal(
  BuildContext context,
) {
  int playerCount = 2;
  List<TipoJugador> playerKinds = List<TipoJugador>.filled(
    playerCount,
    TipoJugador.human,
  );
  String? validationError;

  // Ajusta la lista de tipos al cambiar el numero de jugadores. Las plazas
  // nuevas empiezan como humanas para mantener una configuracion segura.
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
      // El dialogo necesita estado local para cambiar numero/tipo de jugadores
      // sin crear un StatefulWidget especifico solo para este formulario.
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: const Text('Jugadores en partida local'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ForSizes.localPlayerDialogMaxWidth,
              ),
              child: SingleChildScrollView(
                // El contenido puede crecer en pantallas pequenas; el scroll
                // evita que los selectores o botones queden fuera de vista.
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
                          // Al cambiar el numero de jugadores se reajustan las
                          // plazas visibles y se limpia cualquier error previo.
                          playerCount = value;
                          resizePlayerKinds(playerCount);
                          validationError = null;
                        });
                      },
                    ),
                    const SizedBox(height: ForSpacing.lg),
                    const Text('Configura cada plaza como humano o bot.'),
                    const SizedBox(height: ForSpacing.md),
                    // Se genera un selector por plaza para que la configuracion
                    // local pueda mezclar humanos y bots.
                    ...List<Widget>.generate(playerCount, (int index) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: ForSpacing.messageGap,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text('Plaza ${index + 1}')),
                            const SizedBox(width: ForSpacing.md),
                            SizedBox(
                              width: ForSizes.playerKindDropdownWidth,
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
                        padding: const EdgeInsets.only(top: ForSpacing.xs),
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
                  // Se exige al menos un humano para evitar partidas locales
                  // completamente automaticas sin control directo del usuario.
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
