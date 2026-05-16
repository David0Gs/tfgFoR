import 'dart:async';

import 'package:flutter/material.dart';
import 'domain/foundations_of_rome/foundations_of_rome.dart';
import 'application/local_game/local_game.dart';
import 'domain/entrada_leaderboard.dart';
import 'infrastructure/audio/audio_service.dart';
import 'infrastructure/sesion_remota.dart';
import 'infrastructure/persistence/persistencia_partida.dart';
import 'application_config.dart';
import 'presentation/screens/pantalla_menu_principal.dart';
import 'presentation/screens/pantalla_tablero.dart';
import 'presentation/for_theme.dart';
import 'presentation/widgets/seleccion_jugadores_local.dart';

Future<void> _guardarPartida(String jsonString) {
  return descargarPartidaJson(jsonString);
}

Future<Juego?> _cargarPartida() async {
  final String? jsonString = await seleccionarPartidaJson();
  if (jsonString == null || jsonString.trim().isEmpty) {
    return null;
  }
  return Juego.fromJsonString(jsonString);
}

Route<void> _crearRutaMenuPrincipal() {
  return MaterialPageRoute<void>(
    builder: (BuildContext context) => PantallaMenuPrincipal(
      onIniciarPartidaLocal: _abrirPartidaLocal,
      onCargarPartida: _abrirPartidaGuardada,
      onConectarPartidaRemota: _abrirPartidaRemota,
      onMostrarRanking: _mostrarRankingGlobal,
    ),
  );
}

Route<void> _crearRutaTablero({
  required int initialPlayerCount,
  LocalGameConfiguration? initialLocalGameConfiguration,
  Juego? initialGame,
  bool abrirDialogoUnionRemotaAlIniciar = false,
}) {
  return MaterialPageRoute<void>(
    builder: (BuildContext context) => PantallaTablero(
      initialPlayerCount: initialPlayerCount,
      initialLocalGameConfiguration: initialLocalGameConfiguration,
      initialGame: initialGame,
      abrirDialogoUnionRemotaAlIniciar: abrirDialogoUnionRemotaAlIniciar,
      onGuardarPartida: _guardarPartida,
      onSalirAlMenu: _volverAlMenuPrincipal,
    ),
  );
}

Future<void> _abrirPartidaLocal(BuildContext context) async {
  final LocalGameConfiguration? configuration =
      await mostrarSeleccionJugadoresLocal(context);
  if (configuration == null || !context.mounted) {
    return;
  }

  Navigator.of(context).pushReplacement(
    _crearRutaTablero(
      initialPlayerCount: configuration.playerCount,
      initialLocalGameConfiguration: configuration,
    ),
  );
}

Future<void> _abrirPartidaRemota(BuildContext context) async {
  Navigator.of(context).pushReplacement(
    _crearRutaTablero(
      initialPlayerCount: 2,
      abrirDialogoUnionRemotaAlIniciar: true,
    ),
  );
}

Future<void> _abrirPartidaGuardada(BuildContext context) async {
  try {
    final Juego? loadedGame = await _cargarPartida();
    if (loadedGame == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontro ninguna partida guardada.'),
          ),
        );
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      _crearRutaTablero(
        initialPlayerCount: loadedGame.numeroJugadores,
        initialGame: loadedGame,
      ),
    );
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('No se pudo cargar la partida: $e')));
  }
}

Future<void> _mostrarRankingGlobal(BuildContext context) async {
  final TextEditingController urlController = TextEditingController(
    text:
        SesionRemotaController.leerUrlInicialDesdeNavegador() ??
        'ws://localhost:8080',
  );

  if (!context.mounted) {
    urlController.dispose();
    return;
  }

  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (BuildContext dialogContext) {
      Future<List<EntradaClasificacion>>? cargaActual;
      String? ultimoError;
      String? ultimaUrl;

      Future<List<EntradaClasificacion>> iniciarCarga(StateSetter setState) {
        final String url = urlController.text.trim();
        setState(() {
          ultimoError = null;
          ultimaUrl = url;
          cargaActual = SesionRemotaController.cargarLeaderboardRemoto(url);
        });
        return cargaActual!;
      }

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final Future<List<EntradaClasificacion>>? future = cargaActual;

          return AlertDialog(
            title: const Text('Leaderboard global'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL del servidor',
                      hintText: 'ws://localhost:8080',
                    ),
                    onSubmitted: (_) {
                      iniciarCarga(setState);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (future == null)
                    const SizedBox(
                      height: 180,
                      child: Center(
                        child: Text(
                          'Confirma la URL del servidor para cargar el leaderboard.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    FutureBuilder<List<EntradaClasificacion>>(
                      future: future,
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<EntradaClasificacion>> snapshot,
                          ) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const SizedBox(
                                height: 180,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 12),
                                      Text('Cargando top 10 global...'),
                                    ],
                                  ),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              ultimoError = snapshot.error.toString();
                              return SizedBox(
                                height: 180,
                                child: Center(
                                  child: Text(
                                    ultimoError!,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            final List<EntradaClasificacion> entries =
                                snapshot.data ?? const <EntradaClasificacion>[];
                            if (entries.isEmpty) {
                              return const SizedBox(
                                height: 180,
                                child: Center(
                                  child: Text(
                                    'Aun no hay puntuaciones globales registradas.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            return SizedBox(
                              height: 320,
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: entries.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (BuildContext context, int index) {
                                  final EntradaClasificacion entry =
                                      entries[index];
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      child: Text('${index + 1}'),
                                    ),
                                    title: Text(entry.alias),
                                    trailing: Text('${entry.puntuacion} PV'),
                                  );
                                },
                              ),
                            );
                          },
                    ),
                  if (ultimaUrl != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Servidor: $ultimaUrl',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  iniciarCarga(setState);
                },
                child: const Text('Recargar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                },
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
    },
  );

  urlController.dispose();
}

void _volverAlMenuPrincipal(BuildContext context) {
  Navigator.of(context).pushReplacement(_crearRutaMenuPrincipal());
}

Future<void> _inicializarAudioGlobal() async {
  await AudioService.instance.initialize();
  await AudioService.instance.ensureStarted();
}

Future<void> runFlutterApp() async {
  await ApplicationConfig.inicializar();

  runApp(
    ApplicationConfig.envolverInteraccionesGlobales(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ForTheme.materialTheme(),
        home: PantallaMenuPrincipal(
          onIniciarPartidaLocal: _abrirPartidaLocal,
          onCargarPartida: _abrirPartidaGuardada,
          onConectarPartidaRemota: _abrirPartidaRemota,
          onMostrarRanking: _mostrarRankingGlobal,
        ),
      ),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_inicializarAudioGlobal());
  });
}
