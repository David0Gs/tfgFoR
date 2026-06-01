// Pantalla inicial de la aplicacion. Define el menu principal, muestra las
// opciones disponibles al jugador y delega en app_entrypoint.dart los flujos
// que cambian de pantalla o necesitan coordinacion global.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../infrastructure/audio/audio_service.dart';
import '../for_theme.dart';
import '../widgets/contenido_dialog.dart';

const String _assetInstrucciones = 'assets/texts/instrucciones.txt';
const String _assetAgradecimientos = 'assets/texts/agradecimientos.txt';
const String _urlManualReglas =
    'https://www.arcanewonders.com/wp-content/uploads/2021/05/FoR-Core-Rulebook-Spanish_web.pdf';
const String _urlVideotutorial =
    'https://www.youtube.com/watch?v=my8_V8Rcryg&autoplay=1&wide=1';

/// Widget principal del menu.
///
/// Es StatelessWidget porque no guarda estado propio: recibe callbacks para las
/// acciones grandes y consulta AudioService al redibujar el boton de sonido.
class PantallaMenuPrincipal extends StatelessWidget {
  const PantallaMenuPrincipal({
    required this.onIniciarPartidaLocal,
    required this.onCargarPartida,
    required this.onConectarPartidaRemota,
    required this.onMostrarRanking,
    super.key,
  });

  final Future<void> Function(BuildContext context) onIniciarPartidaLocal;
  final Future<void> Function(BuildContext context) onCargarPartida;
  final Future<void> Function(BuildContext context) onConectarPartidaRemota;
  final Future<void> Function(BuildContext context) onMostrarRanking;

  /// Opciones visibles del menu, definidas como datos para pintar botones.
  static const List<_MenuOption> _opciones = <_MenuOption>[
    _MenuOption('Iniciar partida local', _MenuAction.iniciarPartidaLocal),
    _MenuOption('Cargar partida', _MenuAction.cargarPartida),
    _MenuOption('Conectar a partida remota', _MenuAction.conectarPartidaRemota),
    _MenuOption('Ranking', _MenuAction.ranking),
    _MenuOption('Instrucciones', _MenuAction.instrucciones),
    _MenuOption('Agradecimientos, y créditos', _MenuAction.agradecimientos),
    _MenuOption('Salir', _MenuAction.salir),
  ];

  /// Ejecuta la accion asociada a una opcion del menu.
  ///
  /// Las acciones grandes se delegan al entrypoint. Las acciones propias del
  /// menu, como abrir enlaces o creditos, se resuelven directamente aqui.
  Future<void> _manejarOpcion(BuildContext context, _MenuOption opcion) async {
    switch (opcion.action) {
      case _MenuAction.iniciarPartidaLocal:
        await onIniciarPartidaLocal(context);
      case _MenuAction.cargarPartida:
        await onCargarPartida(context);
      case _MenuAction.conectarPartidaRemota:
        await onConectarPartidaRemota(context);
      case _MenuAction.ranking:
        await onMostrarRanking(context);
      case _MenuAction.instrucciones:
        await _mostrarDialogoInstrucciones(context);
      case _MenuAction.agradecimientos:
        await _mostrarDialogoAgradecimientos(context);
      case _MenuAction.salir:
        await _salirDeAplicacion(context);
    }
  }

  /// Solicita al sistema cerrar la aplicacion desde el menu principal.
  Future<void> _salirDeAplicacion(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Para salir en web, cierra la pestaña del navegador.'),
        ),
      );
      return;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        await SystemNavigator.pop();
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        await windowManager.close();
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        await SystemNavigator.pop();
    }
  }

  /// Muestra las instrucciones resumidas y accesos al material original.
  Future<void> _mostrarDialogoInstrucciones(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierColor: ForColors.overlayStrong,
      builder: (BuildContext dialogContext) {
        return ContenidoDialog(
          title: 'Instrucciones',
          assetPath: _assetInstrucciones,
          errorMessage: 'No se pudieron cargar las instrucciones.',
          contentBuilder: (BuildContext context, String texto, bool compact) {
            return _InstruccionesPanel(texto: texto, compact: compact);
          },
          actionsBuilder: (BuildContext _) {
            return <Widget>[
              FilledButton.icon(
                onPressed: () async {
                  await _abrirEnlace(
                    context,
                    url: _urlVideotutorial,
                    error: 'No se pudo abrir el videotutorial.',
                  );
                },
                icon: const Icon(Icons.play_circle),
                label: const Text('Videotutorial'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await _abrirEnlace(
                    context,
                    url: _urlManualReglas,
                    error: 'No se pudo abrir el manual de reglas.',
                  );
                },
                icon: const Icon(Icons.menu_book),
                label: const Text('Manual de reglas'),
              ),
            ];
          },
        );
      },
    );
  }

  /// Muestra el texto de agradecimientos en un dialogo reutilizable.
  Future<void> _mostrarDialogoAgradecimientos(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierColor: ForColors.overlayStrong,
      builder: (BuildContext dialogContext) {
        return const CreditosDialog(assetPath: _assetAgradecimientos);
      },
    );
  }

  /// Abre recursos externos del menu.
  ///
  /// En web se fuerza una pestaña nueva; si no se puede abrir el enlace, se
  /// informa al usuario con un SnackBar.
  Future<void> _abrirEnlace(
    BuildContext context, {
    required String url,
    required String error,
  }) async {
    final bool abierto = await launchUrl(
      Uri.parse(url),
      webOnlyWindowName: '_blank',
    );
    if (abierto || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  /// Construye el layout visual del menu principal.
  @override
  Widget build(BuildContext context) {
    const double menuMinWidth = 240;
    const double menuMaxWidth = 360;
    const double topSpacing = 64;
    const double bottomSpacing = 32;
    final Iterable<_MenuOption> opcionesVisibles = kIsWeb
        ? _opciones.where(
            (_MenuOption opcion) => opcion.action != _MenuAction.salir,
          )
        : _opciones;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/pics/forScreen.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool compactMenu = constraints.maxWidth < 600;
                  final double availableHeight =
                      constraints.maxHeight - topSpacing - bottomSpacing;
                  final double minContentHeight = availableHeight > 0
                      ? availableHeight
                      : 0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      compactMenu ? 12 : 24,
                      topSpacing,
                      compactMenu ? 12 : 24,
                      bottomSpacing,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minContentHeight),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: menuMinWidth,
                            maxWidth: menuMaxWidth,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/pics/forIcon.png',
                                width: 180,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 54),
                              ...opcionesVisibles.map(
                                (_MenuOption opcion) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _MenuButton(
                                    opcion: opcion,
                                    compact: compactMenu,
                                    onPressed: () {
                                      _manejarOpcion(context, opcion);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 16,
                right: 16,
                child: ValueListenableBuilder<bool>(
                  valueListenable: AudioService.instance.isMuted,
                  builder: (BuildContext context, bool isMuted, Widget? child) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: ForColors.panelSoft,
                        borderRadius: BorderRadius.circular(ForRadius.button),
                        border: Border.all(color: ForColors.border),
                      ),
                      child: IconButton(
                        tooltip: isMuted
                            ? 'Activar musica'
                            : 'Silenciar musica',
                        onPressed: () async {
                          await AudioService.instance.toggleMuted();
                        },
                        icon: Icon(
                          isMuted ? Icons.volume_off : Icons.volume_up,
                          color: ForColors.text,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Boton principal del menu.
///
/// Siempre ocupa el ancho del bloque central. En movil solo reduce el padding
/// vertical para que la altura sea mas compacta.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.opcion,
    required this.compact,
    required this.onPressed,
  });

  final _MenuOption opcion;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ForButtonStyles.menuPrimary(compact: compact),
        child: Text(opcion.label, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Modelo interno de cada boton del menu: texto visible y accion asociada.
class _MenuOption {
  const _MenuOption(this.label, this.action);

  final String label;
  final _MenuAction action;
}

/// Acciones posibles del menu.
///
/// Mantenerlas en un enum evita depender de textos para decidir que debe
/// ocurrir al pulsar cada boton.
enum _MenuAction {
  iniciarPartidaLocal,
  cargarPartida,
  conectarPartidaRemota,
  ranking,
  instrucciones,
  agradecimientos,
  salir,
}

/// Panel textual de instrucciones dentro del dialogo comun de contenido.
class _InstruccionesPanel extends StatelessWidget {
  const _InstruccionesPanel({required this.texto, required this.compact});

  final String texto;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? ForSpacing.md : ForSpacing.xl),
      child: Text(
        texto,
        style: compact
            ? ForTypography.creditsParagraph.copyWith(
                fontSize: 13,
                height: 1.45,
              )
            : ForTypography.creditsParagraph,
      ),
    );
  }
}
