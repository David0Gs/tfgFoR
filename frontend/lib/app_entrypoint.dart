// Este archivo contiene la funcion runFlutterApp.
// Actua como coordinador inicial de la aplicacion Flutter.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:for_core/core.dart';
import 'application/local_game/local_game.dart';
import 'infrastructure/audio/audio_service.dart';
import 'infrastructure/sesion_remota.dart';
import 'infrastructure/persistence/persistencia_partida.dart';
import 'application_config.dart';
import 'presentation/screens/pantalla_menu_principal.dart';
import 'presentation/screens/pantalla_tablero.dart';
import 'presentation/for_theme.dart';
import 'presentation/widgets/remote_join_dialog.dart';
import 'presentation/widgets/seleccion_jugadores_local.dart';

/// Crea la ruta de la pantalla principal, que a su vez es la pantalla inicial.
///
/// Desde esta pantalla se puede iniciar una partida local, cargar una partida
/// guardada, conectar a una partida remota o mostrar el ranking global.
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

/// Crea la ruta de la pantalla del tablero.
///
/// Recibe la configuracion inicial de la partida, que puede ser local, remota
/// o cargada desde el almacenamiento local.
Route<void> _crearRutaTablero({
  required int initialPlayerCount,
  LocalGameConfiguration? initialLocalGameConfiguration,
  Juego? initialGame,
  SesionRemotaController? initialRemoteSession,
}) {
  return MaterialPageRoute<void>(
    builder: (BuildContext context) => PantallaTablero(
      initialPlayerCount: initialPlayerCount,
      initialLocalGameConfiguration: initialLocalGameConfiguration,
      initialGame: initialGame,
      initialRemoteSession: initialRemoteSession,
      onGuardarPartida: _guardarPartida,
      onSalirAlMenu: _volverAlMenuPrincipal,
    ),
  );
}

/// Guarda una partida local serializada en JSON.
Future<void> _guardarPartida(String jsonString) {
  return descargarPartidaJson(jsonString);
}

/// Carga una partida local desde un archivo JSON seleccionado por el usuario.
Future<Juego?> _cargarPartida() async {
  final String? jsonString = await seleccionarPartidaJson();
  if (jsonString == null || jsonString.trim().isEmpty) {
    return null;
  }
  return Juego.fromJsonString(jsonString);
}

/// Abre el flujo de seleccion de jugadores y entra al tablero en modo local.
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

/// Abre el dialogo de conexion y entra al tablero en modo remoto.
Future<void> _abrirPartidaRemota(BuildContext context) async {
  // Primero se pide al jugador la URL del servidor, su alias y la sala remota.
  // El dialogo devuelve null si el usuario cancela.
  final Map<String, String>? datosConexion =
      await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (BuildContext dialogContext) {
          return RemoteJoinDialog(
            initialUrl:
                SesionRemotaController.leerUrlInicialDesdeNavegador() ??
                SesionRemotaController.urlServidorLocalPorDefecto,
            initialAlias:
                SesionRemotaController.leerAliasInicialDesdeNavegador() ?? '',
          );
        },
      );
  if (datosConexion == null || !context.mounted) {
    return;
  }
  // Los datos del dialogo llegan como texto porque proceden de controles de UI.
  // Aqui se normalizan antes de intentar abrir la conexion WebSocket.
  final String urlSeleccionada = datosConexion['url'] ?? '';
  final String aliasSeleccionado = datosConexion['alias'] ?? '';
  final String roomAlias = datosConexion['roomAlias'] ?? '';
  final bool createRoom = datosConexion['createRoom'] == 'true';
  final int? players = int.tryParse(datosConexion['players'] ?? '');
  if (urlSeleccionada.isEmpty || aliasSeleccionado.isEmpty) {
    return;
  }
  // La sesion remota encapsula todo el protocolo WebSocket: join, snapshots,
  // reconexion, tokens de sesion y envio de acciones al servidor.
  final SesionRemotaController sesionRemota = SesionRemotaController();
  unawaited(_mostrarDialogoConectandoRemoto(context));
  try {
    await sesionRemota.unirse(
      urlSeleccionada,
      playerName: aliasSeleccionado,
      roomAlias: roomAlias,
      createRoom: createRoom,
      players: players,
    );
  } catch (error) {
    // Si falla la conexion, se cierra el dialogo de espera, se libera la sesion
    // creada y se informa al jugador sin entrar al tablero.
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await sesionRemota.cerrar();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo abrir la partida remota: $error')),
    );
    return;
  }
  // Llegados aqui el servidor ya acepto la union y envio el primer estado de
  // partida. Se cierra el dialogo de espera antes de cambiar de pantalla.
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  // Si la pantalla desaparecio mientras se conectaba, se cierra el WebSocket
  // para no dejar una plaza abierta sin interfaz que la controle.
  if (!context.mounted) {
    await sesionRemota.cerrar();
    return;
  }
  // El tablero recibe tanto el snapshot inicial como la sesion remota viva.
  // Desde este punto, pantalla_tablero escucha cambios enviados por el servidor.
  Navigator.of(context).pushReplacement(
    _crearRutaTablero(
      initialPlayerCount:
          sesionRemota.ultimoSnapshot?.numeroJugadores ?? players ?? 2,
      initialGame: sesionRemota.ultimoSnapshot,
      initialRemoteSession: sesionRemota,
    ),
  );
}

/// Muestra un dialogo de espera mientras se conecta a la partida remota.
Future<void> _mostrarDialogoConectandoRemoto(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (BuildContext dialogContext) {
      return const AlertDialog(
        content: SizedBox(
          width: 260,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 18),
              Flexible(child: Text('Conectando a sala remota...')),
            ],
          ),
        ),
      );
    },
  );
}

/// Abre una partida guardada desde el almacenamiento local.
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

/// Muestra el ranking global consultando el backend indicado por el usuario.
Future<void> _mostrarRankingGlobal(BuildContext context) async {
  // El dialogo permite consultar cualquier servidor. Si la URL viene en la
  // barra del navegador se reutiliza; si no, se propone el servidor local.
  final String defaultServerUrl =
      SesionRemotaController.urlServidorLocalPorDefecto;
  final TextEditingController urlController = TextEditingController(
    text:
        SesionRemotaController.leerUrlInicialDesdeNavegador() ??
        defaultServerUrl,
  );
  if (!context.mounted) {
    urlController.dispose();
    return;
  }
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (BuildContext dialogContext) {
      // Estado propio del dialogo: la carga en curso, el ultimo error y la URL
      // que se esta consultando. Se actualiza al lanzar cada consulta.
      Future<List<EntradaClasificacion>>? cargaActual;
      String? ultimoError;
      String? ultimaUrl;
      // Lanza una consulta remota al leaderboard sin crear una partida. La
      // peticion viaja por SesionRemotaController para reutilizar el protocolo.
      Future<List<EntradaClasificacion>> iniciarCarga(StateSetter setState) {
        final String url = urlController.text.trim();
        setState(() {
          ultimoError = null;
          ultimaUrl = url;
          cargaActual = SesionRemotaController.cargarLeaderboardRemoto(url);
        });
        return cargaActual!;
      }

      // El contenido del dialogo se construye con un StatefulBuilder para poder
      // mostrar carga, error o resultados sin cerrar el dialogo.
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final Future<List<EntradaClasificacion>>? future = cargaActual;
          final Size screenSize = MediaQuery.sizeOf(context);
          final double dialogWidth = (screenSize.width - 48)
              .clamp(320.0, 460.0)
              .toDouble();
          final double maxContentHeight =
              (screenSize.height - 170).clamp(150.0, 430.0).toDouble();
          final double leaderboardContentHeight = (maxContentHeight - 96).clamp(
            120.0,
            320.0,
          ).toDouble();
          // El contenido del dialogo cambia segun el estado del Future:
          // sin carga, cargando, error, lista vacia o ranking con resultados.
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
            title: const Text('Leaderboard global'),
            content: SizedBox(
              width: dialogWidth,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxContentHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: urlController,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'URL del servidor',
                          hintText: defaultServerUrl,
                        ),
                        onSubmitted: (_) {
                          iniciarCarga(setState);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (future == null)
                        // Estado inicial: todavia no se ha pedido el ranking.
                        SizedBox(
                          height: leaderboardContentHeight,
                          child: const Center(
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
                                AsyncSnapshot<List<EntradaClasificacion>>
                                snapshot,
                              ) {
                                if (snapshot.connectionState !=
                                    ConnectionState.done) {
                                  // Mientras la consulta esta pendiente se muestra
                                  // un indicador de progreso dentro del modal.
                                  return SizedBox(
                                    height: leaderboardContentHeight,
                                    child: const Center(
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
                                  // Los fallos de conexion o protocolo se muestran
                                  // sin cerrar el dialogo para poder reintentar.
                                  ultimoError = snapshot.error.toString();
                                  return SizedBox(
                                    height: leaderboardContentHeight,
                                    child: Center(
                                      child: Text(
                                        ultimoError!,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }
                                final List<EntradaClasificacion> entries =
                                    snapshot.data ??
                                    const <EntradaClasificacion>[];
                                // El servidor respondio bien, pero aun no hay
                                // puntuaciones registradas.
                                if (entries.isEmpty) {
                                  return SizedBox(
                                    height: leaderboardContentHeight,
                                    child: const Center(
                                      child: Text(
                                        'Aun no hay puntuaciones globales registradas.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }
                                // Estado correcto: se pinta el top global devuelto
                                // por el servidor.
                                return SizedBox(
                                  height: leaderboardContentHeight,
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: entries.length,
                                    separatorBuilder: (_, _) =>
                                        const Divider(height: 1),
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                          final EntradaClasificacion entry =
                                              entries[index];
                                          return ListTile(
                                            dense: true,
                                            leading: CircleAvatar(
                                              child: Text('${index + 1}'),
                                            ),
                                            title: Text(entry.alias),
                                            trailing: Text(
                                              '${entry.puntuacion} PV',
                                            ),
                                          );
                                        },
                                  ),
                                );
                              },
                        ),
                      if (ultimaUrl != null) ...[
                        const SizedBox(height: 8),
                        // Se deja visible la URL consultada para evitar dudas si
                        // se estan probando varios servidores.
                        Text(
                          'Servidor: $ultimaUrl',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
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

/// Vuelve al menu principal sustituyendo la pantalla actual.
void _volverAlMenuPrincipal(BuildContext context) {
  Navigator.of(context).pushReplacement(_crearRutaMenuPrincipal());
}

/// Inicializa el audio global una vez que la interfaz ya esta montada.
Future<void> _inicializarAudioGlobal() async {
  await AudioService.instance.initialize();
  await AudioService.instance.ensureStarted();
}

/// Inicializa la app Flutter, el tema y las interacciones globales.
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
