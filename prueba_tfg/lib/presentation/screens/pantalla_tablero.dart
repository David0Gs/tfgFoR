import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:window_manager/window_manager.dart';
import '../../application/bots/local_bots.dart';
import '../../application/local_game/local_game.dart';
import '../../domain/entrada_leaderboard.dart';
import '../../domain/alias_online.dart';
import '../../domain/foundations_of_rome/foundations_of_rome.dart';
import '../../infrastructure/audio/audio_service.dart';
import '../../infrastructure/sesion_remota.dart';
import '../../application_config.dart';
import '../../controlador_tablero.dart';
import '../../visor_3d/visor_3d_widget.dart';
import '../for_theme.dart';
import '../widgets/miniatura_edificio_3d.dart';
import '../widgets/seleccion_jugadores_local.dart';

/// Pantalla principal del tablero de juego
/// Contiene el visor 3D y los controles de interfaz
class PantallaTablero extends StatefulWidget {
  const PantallaTablero({
    this.initialPlayerCount = 2,
    this.initialLocalGameConfiguration,
    this.initialGame,
    this.abrirDialogoUnionRemotaAlIniciar = false,
    required this.onGuardarPartida,
    required this.onSalirAlMenu,
    super.key,
  });

  final int initialPlayerCount;
  final LocalGameConfiguration? initialLocalGameConfiguration;
  final Juego? initialGame;
  final bool abrirDialogoUnionRemotaAlIniciar;
  final Future<void> Function(String jsonString) onGuardarPartida;
  final void Function(BuildContext context) onSalirAlMenu;

  @override
  State<PantallaTablero> createState() => _PantallaTableroState();
}

String nombreTipoEdificio(TipoEdificio type) {
  switch (type) {
    case TipoEdificio.residential:
      return 'Residencial';
    case TipoEdificio.commercial:
      return 'Comercial';
    case TipoEdificio.civic:
      return 'Cívico';
  }
}

String? coordFromObjectId(String objectId) {
  if (objectId.startsWith('lot_marker_')) {
    final List<String> partes = objectId.split('_');
    if (partes.length >= 4) {
      return partes.last.toUpperCase();
    }
  }

  if (objectId.startsWith('tile:')) {
    return objectId.replaceFirst('tile:', '').toUpperCase();
  }

  debugPrint(
    "se ha pulsado sobre $objectId, pero no se ha podido extraer una coordenada valida.",
  );
  return null;
}

List<String> occupiedCoordsFromBuiltObjectId(String objectId) {
  if (!objectId.startsWith('built_')) {
    return const <String>[];
  }

  final List<String> parts = objectId.split('_');
  if (parts.length <= 3) {
    return const <String>[];
  }

  final Set<String> coords = <String>{};
  for (final String token in parts.skip(3)) {
    final String normalized = token.trim().toUpperCase();
    if (RegExp(r'^[A-Z][0-9]+$').hasMatch(normalized)) {
      coords.add(normalized);
    }
  }

  return coords.toList(growable: false);
}

class _PantallaTableroState extends State<PantallaTablero> {
  static const String _mensajeSinSustitucionDisponible =
      'No puedes sustituir ese edificio: no hay ningun edificio disponible que pueda ocupar mas parcelas.';
  static const String _assetGifSinSustitucion = 'assets/pics/ahahah.gif';

  final TableroController _tableController = TableroController();
  final SesionRemotaController _sesionRemota = SesionRemotaController();
  final LocalBotTurnRunner _botTurnRunner = LocalBotTurnRunner();
  late Juego _game;
  List<String> deedMarketTags = [];
  String? _coordenadaSeleccionada;
  List<String> _coordenadasSeleccionAnclaje = const <String>[];
  bool _mostrarCatalogoEdificios = false;
  bool _modoColocacionEdificio = false;
  int _rotacionSeleccionada = 0;
  Edificio? _edificioSeleccionado;
  bool _edificioDesdeMonumentos = false;
  bool _mostrandoResumen = false;
  Future<void> _sincronizacion3DEnCurso = Future<void>.value();
  bool _tablero3DListo = false;
  int _versionSnapshotRemotoAplicada = 0;
  int _versionResumenRemotoAplicada = 0;
  int _versionPresenciaRemotaAplicada = 0;
  String? _ultimoErrorRemotoMostrado;

  String _assetParaBuilding(Edificio building) {
    return 'assets/models/building${building.id}.glb';
  }

  String _thumbnailParaBuilding(Edificio building) {
    return 'assets/thumbnails/thumbnail${building.id}.mp4';
  }

  String get _modeloTableroActual {
    return boardModelPathForPlayerCount(_game.numeroJugadores);
  }

  Widget _buildCatalogEntry(
    Edificio building, {
    required bool desdeMonumentos,
    required Color backgroundColor,
    required IconData trailingIcon,
    required Color trailingColor,
    bool enabled = true,
    String? disabledReason,
  }) {
    final String descriptionText = building.description;
    final String? requirementText = desdeMonumentos
        ? _game.monumentRequirementSummary(building.id)
        : null;
    final String? placementStateText = !enabled && disabledReason != null
        ? (disabledReason == 'Selecciona una parcela primero'
              ? 'Estado: selecciona una parcela para validar colocacion.'
              : 'Estado: no colocable ahora. $disabledReason')
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(ForRadii.compactButton),
          child: InkWell(
            borderRadius: BorderRadius.circular(ForRadii.compactButton),
            onTap: enabled
                ? () => _seleccionarEdificio(
                    building,
                    desdeMonumentos: desdeMonumentos,
                  )
                : () {
                    _mostrarMensaje(
                      disabledReason ?? 'No puedes colocar este edificio aquí.',
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: ForSizes.thumbnailWidth,
                    height: ForSizes.thumbnailHeight,
                    child: MiniaturaEdificio3D(
                      videoPath: _thumbnailParaBuilding(building),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${building.name} (${nombreTipoEdificio(building.type)})',
                          style: enabled
                              ? ForTypography.catalogEntryTitle
                              : ForTypography.catalogEntryTitleDisabled,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          descriptionText,
                          style: enabled
                              ? ForTypography.catalogEntryBody
                              : ForTypography.catalogEntryBodyDisabled,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (requirementText != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            requirementText,
                            style: enabled
                                ? ForTypography.catalogEntryBody.copyWith(
                                    color: ForColors.goldLight,
                                  )
                                : ForTypography.catalogEntryBodyDisabled,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (placementStateText != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            placementStateText,
                            style: ForTypography.catalogEntryBodyDisabled,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(trailingIcon, color: trailingColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get _catalogItemCount {
    return 2 +
        (_jugadorActual.availableBuildings.isEmpty
            ? 1
            : _jugadorActual.availableBuildings.length) +
        (_game.monumentosDisponibles.isEmpty
            ? 1
            : _game.monumentosDisponibles.length);
  }

  Widget _buildCatalogListItem(BuildContext context, int index) {
    int cursor = 0;

    if (index == cursor) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Tus edificios', style: ForTypography.sectionTitle),
      );
    }
    cursor++;

    if (_jugadorActual.availableBuildings.isEmpty) {
      if (index == cursor) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No hay edificios disponibles.',
            style: ForTypography.bodyMuted,
          ),
        );
      }
      cursor++;
    } else {
      final int localBuildingIndex = index - cursor;
      if (localBuildingIndex >= 0 &&
          localBuildingIndex < _jugadorActual.availableBuildings.length) {
        final Edificio building =
            _jugadorActual.availableBuildings[localBuildingIndex];
        final String? cannotPlaceReason = _coordenadaSeleccionada != null
          ? _game.puedeColocarEdificio(
            _coordenadaSeleccionada!,
            building,
            isFromMonument: false,
            )
            : 'Selecciona una parcela primero';

        return _buildCatalogEntry(
          building,
          desdeMonumentos: false,
          backgroundColor: ForColors.overlay,
          trailingIcon: Icons.chevron_right,
          trailingColor: ForColors.gold,
          enabled: cannotPlaceReason == null,
          disabledReason: cannotPlaceReason,
        );
      }
      cursor += _jugadorActual.availableBuildings.length;
    }

    if (index == cursor) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: ForColors.borderMuted, height: 18),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Monumentos', style: ForTypography.sectionTitle),
          ),
        ],
      );
    }
    cursor++;

    if (_game.monumentosDisponibles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No hay monumentos disponibles.',
          style: ForTypography.bodyMuted,
        ),
      );
    }

    final int monumentIndex = index - cursor;
    final Edificio building = _game.monumentosDisponibles[monumentIndex];
    final String? cannotPlaceReason = _coordenadaSeleccionada != null
        ? _game.puedeColocarEdificio(
            _coordenadaSeleccionada!,
            building,
            isFromMonument: true,
          )
        : 'Selecciona una parcela primero';

    return _buildCatalogEntry(
      building,
      desdeMonumentos: true,
      backgroundColor: ForColors.infoOverlay,
      trailingIcon: Icons.chevron_right,
      trailingColor: ForColors.infoLight,
      enabled: cannotPlaceReason == null,
      disabledReason: cannotPlaceReason,
    );
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      unawaited(
        windowManager.setMinimumSize(ApplicationConfig.boardMinimumSize),
      );
    }
    _game =
        widget.initialGame ??
        Juego(
          widget.initialLocalGameConfiguration?.playerCount ??
              widget.initialPlayerCount,
          playerKinds: widget.initialLocalGameConfiguration?.playerKinds,
        );
    _sesionRemota.addListener(_manejarCambiosSesionRemota);
    _tableController.registrarClickObjeto(_manejarClickObjeto3D);
    _sincronizarDeedMarketTags();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? urlInicial =
          SesionRemotaController.leerUrlInicialDesdeNavegador();
      final String? aliasInicial =
          SesionRemotaController.leerAliasInicialDesdeNavegador();
      if (widget.abrirDialogoUnionRemotaAlIniciar) {
        unawaited(_mostrarDialogoUnionRemota());
      } else if (urlInicial != null && aliasInicial != null) {
        _conectarSesionRemota(urlInicial, alias: aliasInicial, silent: true);
      } else {
        unawaited(_programarTurnosBotSiProcede());
      }
    });
    debugPrint("Inicializando aplicacion: Foundations of Rome");
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      unawaited(windowManager.setMinimumSize(ApplicationConfig.menuMinimumSize));
    }
    _tableController.ocultarPreviewEdificio();
    _tableController.registrarClickObjeto(null);
    _sesionRemota.removeListener(_manejarCambiosSesionRemota);
    unawaited(_sesionRemota.cerrar());
    super.dispose();
  }

  bool get _modoRemotoActivo => _sesionRemota.modoRemotoActivo;

  bool get _turnoBloqueadoPorRemoto {
    if (!_modoRemotoActivo) {
      return false;
    }
    if (!_sesionRemota.conectado) {
      return true;
    }
    return _sesionRemota.playerId != _game.indiceJugadorActual;
  }

  bool get _turnoBotLocalActivo => !_modoRemotoActivo && _jugadorActual.isBot;

  bool get _interaccionBloqueadaLocalmente =>
      !_modoRemotoActivo &&
      (!_tablero3DListo || _turnoBotLocalActivo || _botTurnRunner.isProcessing);

  String? get _alertaParticipantesRemotos => _sesionRemota.alertaParticipantes;

  Future<void> _manejarCambiosSesionRemota() async {
    if (!mounted) {
      return;
    }

    final int versionSnapshot = _sesionRemota.versionSnapshot;
    if (versionSnapshot != _versionSnapshotRemotoAplicada) {
      _versionSnapshotRemotoAplicada = versionSnapshot;
      final Juego? snapshot = _sesionRemota.ultimoSnapshot;
      if (snapshot != null) {
        await _aplicarJuego(snapshot);
      }
    }

    final int versionResumen = _sesionRemota.versionResumen;
    if (versionResumen != _versionResumenRemotoAplicada) {
      _versionResumenRemotoAplicada = versionResumen;
      final Map<String, dynamic>? resumen = _sesionRemota.ultimoResumen;
      if (resumen != null) {
        await _mostrarResumen(resumen);
      }
    }

    final int versionPresencia = _sesionRemota.versionPresencia;
    if (versionPresencia != _versionPresenciaRemotaAplicada) {
      _versionPresenciaRemotaAplicada = versionPresencia;
    }

    final String? error = _sesionRemota.ultimoError;
    if (error != null && error != _ultimoErrorRemotoMostrado) {
      _ultimoErrorRemotoMostrado = error;
      _mostrarMensajeDiferido(error);
    }
    if (error == null) {
      _ultimoErrorRemotoMostrado = null;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _conectarSesionRemota(
    String url, {
    required String alias,
    bool silent = false,
  }) async {
    try {
      await _sesionRemota.unirse(url, playerName: alias);
      if (!silent) {
        _mostrarMensajeDiferido('Conectado a $url con alias $alias.');
      }
    } catch (e) {
      // El listener de la sesión remota ya publica el error y evita duplicados.
    }
  }

  Future<void> _mostrarDialogoUnionRemota() async {
    final TextEditingController urlController = TextEditingController(
      text:
          _sesionRemota.serverUrl ??
          SesionRemotaController.leerUrlInicialDesdeNavegador() ??
          'ws://localhost:9999',
    );
    final TextEditingController aliasController = TextEditingController(
      text:
          _sesionRemota.playerAlias ??
          SesionRemotaController.leerAliasInicialDesdeNavegador() ??
          '',
    );
    String? aliasError;

    final Map<String, String>?
    datosConexion = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) {
        void confirmarUnion(StateSetter setDialogState) {
          final String alias = AliasOnline.normalizar(aliasController.text);
          final String? error = AliasOnline.mensajeError(alias);
          if (error != null) {
            setDialogState(() {
              aliasError = error;
            });
            return;
          }

          Navigator.of(dialogContext, rootNavigator: true).pop(<String, String>{
            'url': urlController.text.trim(),
            'alias': alias,
          });
        }

        return PointerInterceptor(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return AlertDialog(
                title: const Text('Unirse a partida'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          labelText: 'URL del servidor',
                          hintText: 'ws://localhost:9999',
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: aliasController,
                        maxLength: AliasOnline.longitud,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Alias online',
                          hintText: 'ABC',
                          helperText:
                              '3 caracteres exactos. Se muestran en ranking y resumen final.',
                          errorText: aliasError,
                        ),
                        onChanged: (_) {
                          if (aliasError == null) {
                            return;
                          }
                          setDialogState(() {
                            aliasError = null;
                          });
                        },
                        onSubmitted: (_) => confirmarUnion(setDialogState),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                    },
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => confirmarUnion(setDialogState),
                    child: const Text('Unirse'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    urlController.dispose();
    aliasController.dispose();

    if (datosConexion == null) {
      if (widget.abrirDialogoUnionRemotaAlIniciar) {
        await _salirAlMenu();
      }
      return;
    }
    final String urlSeleccionada = datosConexion['url'] ?? '';
    final String aliasSeleccionado = datosConexion['alias'] ?? '';
    if (urlSeleccionada.isEmpty || aliasSeleccionado.isEmpty) {
      return;
    }
    await _conectarSesionRemota(urlSeleccionada, alias: aliasSeleccionado);
  }

  Future<void> _mostrarLeaderboardRemoto() async {
    if (!_sesionRemota.conectado) {
      _mostrarMensaje(
        'Conectate a una partida remota para ver el leaderboard.',
      );
      return;
    }

    unawaited(_sesionRemota.solicitarLeaderboard());

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) {
        return PointerInterceptor(
          child: AnimatedBuilder(
            animation: _sesionRemota,
            builder: (BuildContext context, Widget? child) {
              final List<EntradaClasificacion> entries =
                  _sesionRemota.leaderboard;
              final bool cargando = _sesionRemota.cargandoLeaderboard;
              final String? error = _sesionRemota.ultimoErrorLeaderboard;

              Widget contenido;
              if (cargando && entries.isEmpty) {
                contenido = const SizedBox(
                  height: 160,
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
              } else if (error != null && entries.isEmpty) {
                contenido = SizedBox(
                  height: 180,
                  child: Center(
                    child: Text(error, textAlign: TextAlign.center),
                  ),
                );
              } else if (entries.isEmpty) {
                contenido = const SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      'Aun no hay puntuaciones globales registradas.',
                    ),
                  ),
                );
              } else {
                contenido = SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (error != null) ...[
                        Text(error, style: ForTypography.errorBody),
                        const SizedBox(height: 12),
                      ],
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (BuildContext context, int index) {
                            final EntradaClasificacion entry = entries[index];
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
                      ),
                    ],
                  ),
                );
              }

              return AlertDialog(
                title: const Text('Leaderboard global'),
                content: contenido,
                actions: [
                  TextButton(
                    onPressed: _sesionRemota.cargandoLeaderboard
                        ? null
                        : () {
                            unawaited(_sesionRemota.solicitarLeaderboard());
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
          ),
        );
      },
    );
  }

  bool _puedeActuarRemotamente(String accion) {
    if (!_tablero3DListo) {
      _mostrarMensaje('Espera a que cargue el tablero para $accion.');
      return false;
    }

    if (!_modoRemotoActivo) {
      if (_interaccionBloqueadaLocalmente) {
        _mostrarMensaje('Espera a que termine el turno del bot para $accion.');
        return false;
      }
      return true;
    }
    if (!_sesionRemota.conectado) {
      _mostrarMensaje('La sesion remota aun no esta conectada.');
      return false;
    }
    if (_turnoBloqueadoPorRemoto) {
      _mostrarMensaje('Espera a tu turno para $accion.');
      return false;
    }
    return true;
  }

  void _sincronizarDeedMarketTags() {
    deedMarketTags = List<String>.generate(_game.mercado.length, (index) {
      final CartaEscritura carta = _game.mercado[index];
      return '${carta.coord} (Coste: ${costes[index]})';
    });

    if (deedMarketTags.isEmpty) {
      deedMarketTags = const ['Mercado vacío'];
    }
  }

  Future<void> _sincronizarMarcadores3D({
    Set<String> edificiosOcultos = const <String>{},
  }) {
    if (!_tablero3DListo) {
      return Future<void>.value();
    }

    final Future<void> siguienteSincronizacion = _sincronizacion3DEnCurso
        .catchError((_) {})
        .then((_) async {
          if (!mounted) {
            return;
          }
          await _tableController.sincronizarMarcadoresLotes(_game);
          await _tableController.sincronizarEdificiosConstructores(
            _game,
            buildingIdsOcultos: edificiosOcultos,
          );
        });
    _sincronizacion3DEnCurso = siguienteSincronizacion;
    return siguienteSincronizacion;
  }

  Future<void> _programarTurnosBotSiProcede() async {
    if (!mounted || _modoRemotoActivo || !_tablero3DListo) {
      return;
    }

    await _botTurnRunner.processPendingTurns(
      game: _game,
      localModeEnabled: !_modoRemotoActivo,
      synchronizeState: () => _sincronizarEstadoJuego(programarBots: false),
      executeAction: _ejecutarAccionBotConVisual,
      isMounted: () => mounted,
    );

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _sincronizarEstadoJuego({
    bool programarBots = true,
    Set<String> edificiosOcultos = const <String>{},
  }) async {
    if (!mounted) return;
    setState(() {
      _sincronizarDeedMarketTags();
    });
    await _sincronizarMarcadores3D(edificiosOcultos: edificiosOcultos);
    await _mostrarResumenPendienteSiExiste();
    if (programarBots) {
      await _programarTurnosBotSiProcede();
    }
  }

  Future<void> _ejecutarIngreso() async {
    if (!_puedeActuarRemotamente('cobrar ingresos')) {
      return;
    }

    if (_modoRemotoActivo) {
      await _sesionRemota.enviarIngreso();
      return;
    }

    _game.accionIngresos();
    await _sincronizarEstadoJuego();
  }

  void _mostrarMensaje(String mensaje, {Duration? duration}) {
    if (!mounted) return;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: _buildContenidoMensaje(mensaje),
          duration: duration ?? const Duration(seconds: 4),
        ),
      );
  }

  Widget _buildContenidoMensaje(String mensaje) {
    if (mensaje != _mensajeSinSustitucionDisponible) {
      return Align(
        alignment: Alignment.center,
        child: Text(mensaje, textAlign: TextAlign.center),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildGifMensaje(),
        const SizedBox(width: 10),
        Flexible(
          child: Text(mensaje, textAlign: TextAlign.center),
        ),
        const SizedBox(width: 10),
        _buildGifMensaje(),
      ],
    );
  }

  Widget _buildGifMensaje() {
    return SizedBox(
      width: 34,
      height: 34,
      child: Image.asset(_assetGifSinSustitucion, fit: BoxFit.contain),
    );
  }

  void _mostrarMensajeDiferido(String mensaje) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mostrarMensaje(mensaje);
    });
  }

  void _restablecerEstadoInteractivo() {
    _coordenadasSeleccionAnclaje = const <String>[];
    _mostrarCatalogoEdificios = false;
    _modoColocacionEdificio = false;
    _coordenadaSeleccionada = null;
    _rotacionSeleccionada = 0;
    _edificioSeleccionado = null;
    _edificioDesdeMonumentos = false;
  }

  Future<void> _aplicarJuego(Juego siguienteJuego) async {
    final String modeloAnterior = _modeloTableroActual;
    final String modeloNuevo = boardModelPathForPlayerCount(
      siguienteJuego.numeroJugadores,
    );
    final bool cambiaModeloTablero = modeloAnterior != modeloNuevo;

    await _tableController.ocultarPreviewEdificio();

    if (!mounted) {
      return;
    }

    setState(() {
      _game = siguienteJuego;
      _restablecerEstadoInteractivo();
      _sincronizarDeedMarketTags();
      if (cambiaModeloTablero) {
        _tablero3DListo = false;
      }
    });

    if (!cambiaModeloTablero) {
      await _sincronizarMarcadores3D();
    }

    await _programarTurnosBotSiProcede();
  }

  Future<void> _manejarModeloTableroListo(String modelPath) async {
    if (!mounted ||
        (modelPath != 'main' && modelPath != _modeloTableroActual)) {
      return;
    }

    setState(() {
      _tablero3DListo = true;
    });

    await _sincronizarMarcadores3D();
    await _programarTurnosBotSiProcede();
  }

  Future<void> _guardarPartida() async {
    try {
      await widget.onGuardarPartida(_game.toJsonString());
      _mostrarMensaje('Partida guardada correctamente.');
    } catch (e) {
      _mostrarMensaje('No se pudo guardar la partida: $e');
    }
  }

  Future<void> _salirAlMenu() async {
    await _tableController.ocultarPreviewEdificio();

    if (!mounted) {
      return;
    }
    widget.onSalirAlMenu(context);
  }

  Jugador get _jugadorActual => _game.players[_game.indiceJugadorActual];

  Color _colorJugador(int playerId) {
    return ForColors.getPlayerColor(playerId);
  }

  int _totalRotacionesVisuales(Edificio building) {
    final bool esUnaParcela =
        building.rotations.length == 1 && building.rotations.first.length == 1;
    return esUnaParcela ? 4 : building.rotations.length;
  }

  int _compareCoords(String a, String b) {
    final int colA = a.codeUnitAt(0);
    final int colB = b.codeUnitAt(0);
    if (colA != colB) {
      return colA.compareTo(colB);
    }

    final int rowA = int.parse(a.substring(1));
    final int rowB = int.parse(b.substring(1));
    return rowA.compareTo(rowB);
  }

  bool _hayEdificiosColocablesEn(String coord) {
    for (final Edificio building in _jugadorActual.availableBuildings) {
      if (_game.puedeColocarEdificio(
            coord,
            building,
            isFromMonument: false,
          ) ==
          null) {
        return true;
      }
    }

    for (final Edificio building in _game.monumentosDisponibles) {
      if (_game.puedeColocarEdificio(
            coord,
            building,
            isFromMonument: true,
          ) ==
          null) {
        return true;
      }
    }

    return false;
  }

  bool _hayEdificiosColocablesEnAlguna(Iterable<String> coords) {
    return coords.any(_hayEdificiosColocablesEn);
  }

  void _mostrarMensajeSinSustitucionDisponible() {
    _mostrarMensaje(_mensajeSinSustitucionDisponible);
  }

  void _mostrarSeleccionAnclajeEdificio(List<String> occupiedCoords) {
    setState(() {
      _coordenadasSeleccionAnclaje = occupiedCoords;
      _mostrarCatalogoEdificios = false;
      _modoColocacionEdificio = false;
      _coordenadaSeleccionada = null;
      _rotacionSeleccionada = 0;
      _edificioSeleccionado = null;
      _edificioDesdeMonumentos = false;
    });
  }

  void _confirmarSeleccionAnclaje(String coord) {
    if (!_hayEdificiosColocablesEn(coord)) {
      setState(() {
        _coordenadasSeleccionAnclaje = const <String>[];
        _mostrarCatalogoEdificios = false;
        _modoColocacionEdificio = false;
        _coordenadaSeleccionada = null;
        _rotacionSeleccionada = 0;
        _edificioSeleccionado = null;
        _edificioDesdeMonumentos = false;
      });
      _mostrarMensajeSinSustitucionDisponible();
      return;
    }

    setState(() {
      _coordenadasSeleccionAnclaje = const <String>[];
      _coordenadaSeleccionada = coord;
      _mostrarCatalogoEdificios = true;
      _rotacionSeleccionada = 0;
    });
  }

  void _cancelarSeleccionAnclaje() {
    setState(() {
      _coordenadasSeleccionAnclaje = const <String>[];
      _mostrarCatalogoEdificios = false;
      _modoColocacionEdificio = false;
      _coordenadaSeleccionada = null;
      _rotacionSeleccionada = 0;
      _edificioSeleccionado = null;
      _edificioDesdeMonumentos = false;
    });
  }

  Future<void> _manejarClickObjeto3D(String objectId) async {
    if (!mounted || _game.partidaFinalizada) return;

    if (!_puedeActuarRemotamente('interactuar con el tablero')) {
      return;
    }

    if (_coordenadasSeleccionAnclaje.isNotEmpty) {
      return;
    }

    if (_modoColocacionEdificio) {
      await _confirmarColocacionEdificio();
      return;
    }

    final Jugador jugadorActual = _game.players[_game.indiceJugadorActual];

    String? coord = coordFromObjectId(objectId);
    if (coord == null && objectId.startsWith('built_')) {
      final List<String> ownedCoords = occupiedCoordsFromBuiltObjectId(objectId)
          .where((String c) => jugadorActual.lots.contains(c))
          .toSet()
          .toList()
        ..sort(_compareCoords);

      if (ownedCoords.isEmpty) {
        return;
      }

      if (!_hayEdificiosColocablesEnAlguna(ownedCoords)) {
        _cancelarSeleccionAnclaje();
        _mostrarMensajeSinSustitucionDisponible();
        return;
      }

      if (ownedCoords.length > 1) {
        _mostrarSeleccionAnclajeEdificio(ownedCoords);
        return;
      }

      coord = ownedCoords.first;
    }

    if (coord == null || !jugadorActual.lots.contains(coord)) {
      return;
    }

    if (_game.edificios.containsKey(coord) &&
        !_hayEdificiosColocablesEn(coord)) {
      _mostrarMensajeSinSustitucionDisponible();
      return;
    }

    setState(() {
      _coordenadaSeleccionada = coord;
      _mostrarCatalogoEdificios = true;
      _rotacionSeleccionada = 0;
    });
  }

  Future<void> _seleccionarEdificio(
    Edificio building, {
    required bool desdeMonumentos,
  }) async {
    if (!_puedeActuarRemotamente('seleccionar un edificio')) {
      return;
    }

    final String? coord = _coordenadaSeleccionada;
    if (coord == null) return;

    setState(() {
      _mostrarCatalogoEdificios = false;
      _modoColocacionEdificio = true;
      _rotacionSeleccionada = 0;
      _edificioSeleccionado = building;
      _edificioDesdeMonumentos = desdeMonumentos;
    });

    await _tableController.mostrarPreviewEdificio(
      coord,
      modelPath: _assetParaBuilding(building),
      templateId: building.id,
      rotationIndex: _rotacionSeleccionada,
    );
    await _actualizarEdificiosOcultosPorPreview();
  }

  Future<void> _actualizarEdificiosOcultosPorPreview() async {
    final String? coord = _coordenadaSeleccionada;
    final Edificio? building = _edificioSeleccionado;
    if (!_modoColocacionEdificio || coord == null || building == null) {
      await _tableController.restaurarEdificiosOcultosPorPreview();
      return;
    }

    try {
      final List<String> targetCoords = _game.targetCoordsForPlacement(
        coord,
        building,
        _rotacionSeleccionada,
      );
      await _tableController.ocultarEdificiosEnCoordenadas(targetCoords);
    } on RuleError {
      await _tableController.restaurarEdificiosOcultosPorPreview();
    }
  }

  Future<void> _rotarPreviewPorRueda(bool haciaSiguiente) async {
    final Edificio? building = _edificioSeleccionado;
    if (!_modoColocacionEdificio || building == null) {
      return;
    }
    if (!_puedeActuarRemotamente('rotar un edificio')) {
      return;
    }

    final int totalRotaciones = _totalRotacionesVisuales(building);
    if (totalRotaciones <= 1) {
      return;
    }
    final int delta = haciaSiguiente ? 1 : -1;

    setState(() {
      _rotacionSeleccionada = (_rotacionSeleccionada + delta) % totalRotaciones;
      if (_rotacionSeleccionada < 0) {
        _rotacionSeleccionada += totalRotaciones;
      }
    });

    await _tableController.actualizarRotacionPreviewEdificio(
      _rotacionSeleccionada,
      templateId: building.id,
    );
    await _actualizarEdificiosOcultosPorPreview();
  }

  Future<bool> _ejecutarConstruccionConVisual({
    required String coord,
    required Edificio building,
    required int rotationIndex,
    required int buildingIdx,
    required bool desdeMonumentos,
    required Future<bool> Function() aplicarConstruccion,
    bool previewYaVisible = false,
    bool programarBotsAlFinal = false,
  }) async {
    if (!previewYaVisible) {
      await _tableController.mostrarPreviewEdificio(
        coord,
        modelPath: _assetParaBuilding(building),
        templateId: building.id,
        rotationIndex: rotationIndex,
      );

      try {
        final List<String> targetCoords = _game.targetCoordsForPlacement(
          coord,
          building,
          rotationIndex,
        );
        await _tableController.ocultarEdificiosEnCoordenadas(targetCoords);
      } on RuleError {
        await _tableController.restaurarEdificiosOcultosPorPreview();
      }
    }

    late final Future<void> asentamientoPreview;
    final bool construccionOk;
    try {
      _game.validarConstruccion(
        coord,
        building,
        rotationIndex,
        buildingIdx,
        desdeMonumentos,
      );
      asentamientoPreview = _tableController.asentarPreviewEdificio(coord);
      construccionOk = await aplicarConstruccion();
    } on RuleError catch (error) {
      if (previewYaVisible && _modoColocacionEdificio) {
        await _actualizarEdificiosOcultosPorPreview();
      } else {
        await _tableController.restaurarEdificiosOcultosPorPreview();
      }
      _mostrarMensaje(error.message);
      return false;
    }

    if (!construccionOk) {
      await asentamientoPreview;
      await _tableController.ocultarPreviewEdificio();
      await _tableController.restaurarEdificiosOcultosPorPreview();
      return false;
    }

    final String? edificioConstruidoId = _modoRemotoActivo
        ? null
        : _tableController.buildingSceneIdEnCoordenada(_game, coord);
    final Set<String> edificiosOcultos = edificioConstruidoId == null
        ? const <String>{}
        : <String>{edificioConstruidoId};

    if (!_modoRemotoActivo) {
      await Future.wait(<Future<void>>[
        asentamientoPreview,
        _sincronizarEstadoJuego(
          programarBots: false,
          edificiosOcultos: edificiosOcultos,
        ),
      ]);
    } else {
      await asentamientoPreview;
    }

    if (edificioConstruidoId != null) {
      await _tableController.mostrarEdificioConstruido(edificioConstruidoId);
    }
    await _tableController.ocultarPreviewEdificio();

    if (programarBotsAlFinal && !_modoRemotoActivo) {
      await _programarTurnosBotSiProcede();
    }

    return true;
  }

  Future<void> _confirmarColocacionEdificio() async {
    if (!_puedeActuarRemotamente('construir')) {
      return;
    }

    final String? coord = _coordenadaSeleccionada;
    final Edificio? building = _edificioSeleccionado;
    if (coord == null || building == null) {
      return;
    }

    final int buildingIdx = _edificioDesdeMonumentos
        ? _game.monumentosDisponibles.indexWhere((b) => b.id == building.id)
        : _jugadorActual.availableBuildings.indexWhere(
            (b) => b.id == building.id,
          );

    if (buildingIdx < 0) {
      if (mounted) {
        final String fuente = _edificioDesdeMonumentos
            ? 'en monumentos globales'
            : 'en tus edificios';
        _mostrarMensajeDiferido(
          'No esta disponible ${building.name} ($fuente).',
        );
      }
      return;
    }

    final bool construccionOk = await _ejecutarConstruccionConVisual(
      coord: coord,
      building: building,
      rotationIndex: _rotacionSeleccionada,
      buildingIdx: buildingIdx,
      desdeMonumentos: _edificioDesdeMonumentos,
      previewYaVisible: true,
      programarBotsAlFinal: true,
      aplicarConstruccion: () {
        if (_modoRemotoActivo) {
          return _sesionRemota.construir(
            originCoord: coord,
            templateId: building.id,
            rotationIndex: _rotacionSeleccionada,
            isFromMonument: _edificioDesdeMonumentos,
          );
        }

        return Future<bool>.value(
          _game.construir(
            coord,
            building,
            _rotacionSeleccionada,
            buildingIdx,
            _edificioDesdeMonumentos,
          ),
        );
      },
    );

    if (!construccionOk) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _modoColocacionEdificio = false;
      _coordenadaSeleccionada = null;
      _rotacionSeleccionada = 0;
      _edificioSeleccionado = null;
      _edificioDesdeMonumentos = false;
    });
  }

  Future<void> _ejecutarAccionBotConVisual(BotPlannedAction action) async {
    switch (action.type) {
      case BotActionType.build:
        await _ejecutarConstruccionConVisual(
          coord: action.originCoord!,
          building: action.building!,
          rotationIndex: action.rotationIndex!,
          buildingIdx: action.buildingIndex!,
          desdeMonumentos: action.fromMonument,
          aplicarConstruccion: () {
            return Future<bool>.value(
              _game.construir(
                action.originCoord!,
                action.building!,
                action.rotationIndex!,
                action.buildingIndex!,
                action.fromMonument,
              ),
            );
          },
        );
      case BotActionType.buyDeed:
        action.apply(_game);
        await _sincronizarEstadoJuego(programarBots: false);
      case BotActionType.income:
        action.apply(_game);
        await _sincronizarEstadoJuego(programarBots: false);
    }
  }

  Future<void> _cancelarColocacionEdificio() async {
    await _tableController.ocultarPreviewEdificio();
    await _tableController.restaurarEdificiosOcultosPorPreview();
    if (!mounted) return;
    setState(() {
      _coordenadasSeleccionAnclaje = const <String>[];
      _modoColocacionEdificio = false;
      _mostrarCatalogoEdificios = false;
      _coordenadaSeleccionada = null;
      _rotacionSeleccionada = 0;
      _edificioSeleccionado = null;
      _edificioDesdeMonumentos = false;
    });
  }

  void _manejarPointerColocacion(PointerDownEvent event) {
    if (!_modoColocacionEdificio) {
      return;
    }

    if ((event.buttons & kSecondaryMouseButton) != 0) {
      unawaited(_cancelarColocacionEdificio());
      return;
    }

    if ((event.buttons & kPrimaryMouseButton) != 0) {
      unawaited(_confirmarColocacionEdificio());
    }
  }

  void _manejarRuedaColocacion(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _modoColocacionEdificio) {
      unawaited(_rotarPreviewPorRueda(event.scrollDelta.dy > 0));
    }
  }

  Future<void> _mostrarResumenPendienteSiExiste() async {
    if (!mounted || _mostrandoResumen) return;

    final Map<String, dynamic>? resumen = _game.consumirResumenPendiente();
    if (resumen == null) return;

    await _mostrarResumen(resumen);

    if (!mounted) return;
    _game.confirmarResumenPendiente();
    setState(() {
      _sincronizarDeedMarketTags();
    });
    await _sincronizarMarcadores3D();
  }

  Future<void> _mostrarResumen(Map<String, dynamic> resumen) async {
    if (!mounted || _mostrandoResumen) return;

    _mostrandoResumen = true;
    final List<String> lineas = (resumen['lines'] as List<dynamic>)
        .map((linea) => linea.toString())
        .toList();

    final bool? confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) {
        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: ForColors.panelMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ForRadii.panel),
              side: const BorderSide(color: ForColors.gold, width: 1.2),
            ),
            title: Text(
              resumen['title'] as String,
              style: ForTypography.panelTitle,
            ),
            content: SizedBox(
              width: ForSizes.catalogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lineas
                      .map(
                        (linea) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(linea, style: ForTypography.alertBody),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Confirmar'),
              ),
            ],
          ),
        );
      },
    );

    _mostrandoResumen = false;
    if (confirmado != true) return;
  }

  bool _puedeConsultarPanelJugador(Jugador player) {
    return player.id != _jugadorActual.id && !_jugadorActual.isBot;
  }

  int _contarEdificiosJugador(Jugador player) {
    final Set<Propiedad> edificiosUnicos = <Propiedad>{
      for (final Propiedad propiedad in _game.edificios.values)
        if (propiedad.ownerId == player.id) propiedad,
    };
    return edificiosUnicos.length;
  }

  Future<void> _mostrarEstadisticasJugador(Jugador player) async {
    if (!_puedeConsultarPanelJugador(player) || !mounted) {
      return;
    }

    final int edificiosConstruidos = _contarEdificiosJugador(player);

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) {
        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: ForColors.panelMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ForRadii.panel),
              side: BorderSide(color: _colorJugador(player.id), width: 1.2),
            ),
            title: Text(
              'Estadisticas de ${player.name}',
              style: ForTypography.panelTitle.copyWith(
                color: _colorJugador(player.id),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPlayerStat('Monedas', '${player.coins}'),
                const SizedBox(height: 6),
                _buildPlayerStat('PV', '${player.glory}'),
                const SizedBox(height: 6),
                _buildPlayerStat('Población', '${player.populationTrack}'),
                const SizedBox(height: 6),
                _buildPlayerStat('Marcadores', '${player.availableMarkers}/8'),
                const SizedBox(height: 6),
                _buildPlayerStat('Parcelas', '${player.lots.length}'),
                const SizedBox(height: 6),
                _buildPlayerStat('Edificios', '$edificiosConstruidos'),
                if (player.isBot) ...[
                  const SizedBox(height: 12),
                  const Text('Jugador controlado por bot', style: ForTypography.helper),
                ],
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerInfoCard(Jugador player) {
    final bool esJugadorActivo = player.id == _game.indiceJugadorActual;
    final Color colorJugador = _colorJugador(player.id);
    final bool panelConsultable = _puedeConsultarPanelJugador(player);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ForRadii.panel),
        onTap: panelConsultable ? () => _mostrarEstadisticasJugador(player) : null,
        child: Container(
          width: ForSizes.playerPanelWidth,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: esJugadorActivo ? ForColors.panelActive : ForColors.panelDark,
            borderRadius: BorderRadius.circular(ForRadii.panel),
            border: Border.all(
              color: esJugadorActivo ? colorJugador : ForColors.borderMuted,
              width: esJugadorActivo ? 2.2 : 1,
            ),
            boxShadow: esJugadorActivo
                ? [
                    BoxShadow(
                      color: colorJugador.withValues(alpha: 0.30),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                player.name,
                style: ForTypography.playerName.copyWith(color: colorJugador),
              ),
              if (panelConsultable) ...[
                const SizedBox(height: 4),
                const Text('Toca para ver estadisticas', style: ForTypography.helper),
              ],
              if (esJugadorActivo) ...[
                if (player.isBot) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ForColors.borderSubtle,
                      borderRadius: BorderRadius.circular(ForRadii.pill),
                      border: Border.all(color: ForColors.borderMuted),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_toy, size: 12, color: ForColors.textMuted),
                        SizedBox(width: 4),
                        Text('Bot', style: ForTypography.badge),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Turno automatico en partidas locales',
                    style: ForTypography.helper,
                  ),
                ],
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlayerStat('Monedas', '${player.coins}'),
                    const SizedBox(height: 4),
                    _buildPlayerStat('PV', '${player.glory}'),
                    const SizedBox(height: 4),
                    _buildPlayerStat('Población', '${player.populationTrack}'),
                    const SizedBox(height: 4),
                    _buildPlayerStat('Marcadores', '${player.availableMarkers}/8'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerStat(String label, String value) {
    return RichText(
      text: TextSpan(
        style: ForTypography.smallButton,
        children: [
          TextSpan(text: '$label: ', style: ForTypography.playerStatLabel),
          TextSpan(text: value, style: ForTypography.playerStatValue),
        ],
      ),
    );
  }

  Widget _buildSeleccionAnclajeOverlay() {
    return PointerInterceptor(
      child: Container(
        color: ForColors.overlay,
        child: Center(
          child: IntrinsicWidth(
            child: Container(
              padding: const EdgeInsets.all(ForSpacing.lg),
              decoration: BoxDecoration(
                color: ForColors.panelMuted,
                borderRadius: BorderRadius.circular(ForRadii.panel),
                border: Border.all(color: ForColors.gold),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Selecciona la parcela de origen',
                    style: ForTypography.panelTitle,
                  ),
                  const SizedBox(height: ForSpacing.md),
                  ..._coordenadasSeleccionAnclaje.map((String coord) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Center(
                        child: Material(
                          color: ForColors.overlay,
                          borderRadius: BorderRadius.circular(
                            ForRadii.compactButton,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              ForRadii.compactButton,
                            ),
                            onTap: () => _confirmarSeleccionAnclaje(coord),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(coord, style: ForTypography.panelBody),
                                  const SizedBox(width: 24),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: ForColors.gold,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: ForSpacing.sm),
                  Center(
                    child: OutlinedButton(
                      onPressed: _cancelarSeleccionAnclaje,
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: ForSizes.toolbarButtonHeight,
        height: ForSizes.toolbarButtonHeight,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ForButtonStyles.toolbar().copyWith(
            padding: WidgetStateProperty.all(EdgeInsets.zero),
          ),
          child: Icon(icon, size: ForSizes.icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // const SingleActivator(LogicalKeyboardKey.keyC): () =>
        //     _tableController.resetearVista(),
        // const SingleActivator(LogicalKeyboardKey.keyI): () =>
        //     _ejecutarIngreso(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: ForColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                // Visor 3D principal
                Visor3D(
                  key: ValueKey<String>(_modeloTableroActual),
                  controller: _tableController,
                  modelPath: _modeloTableroActual,
                  onModelLoaded: _manejarModeloTableroListo,
                ),

                if (_modoColocacionEdificio)
                  Positioned.fill(
                    child: PointerInterceptor(
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _manejarPointerColocacion,
                        onPointerSignal: _manejarRuedaColocacion,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),

                // Botón de controles
                Positioned(
                  bottom: 30,
                  right: 20,
                  child: PointerInterceptor(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: AudioService.instance.isMuted,
                          builder:
                              (
                                BuildContext context,
                                bool isMuted,
                                Widget? child,
                              ) {
                                return _buildToolbarIconButton(
                                  tooltip: isMuted
                                      ? 'Activar musica'
                                      : 'Silenciar musica',
                                  icon: isMuted
                                      ? Icons.volume_off
                                      : Icons.volume_up,
                                  onPressed: () async {
                                    await AudioService.instance.toggleMuted();
                                  },
                                );
                              },
                        ),
                        const SizedBox(height: 5),
                        _buildToolbarIconButton(
                          tooltip: 'Centrar vista',
                          icon: Icons.center_focus_strong,
                          onPressed: () => _tableController.resetearVista(),
                        ),
                        const SizedBox(height: 5),
                        if (_modoRemotoActivo) ...[
                          _buildToolbarIconButton(
                            tooltip: 'Leaderboard',
                            icon: Icons.leaderboard,
                            onPressed: _sesionRemota.conectado
                                ? _mostrarLeaderboardRemoto
                                : null,
                          ),
                          const SizedBox(height: 5),
                        ],
                        _buildToolbarIconButton(
                          tooltip: 'Cobrar',
                          icon: Icons.attach_money,
                          onPressed:
                              _turnoBloqueadoPorRemoto ||
                                  _interaccionBloqueadaLocalmente
                              ? null
                              : _ejecutarIngreso,
                        ),
                        const SizedBox(height: 5),
                        _buildToolbarIconButton(
                          tooltip: 'Guardar',
                          icon: Icons.save_alt,
                          onPressed: _modoRemotoActivo ? null : _guardarPartida,
                        ),
                        const SizedBox(height: 5),
                        _buildToolbarIconButton(
                          tooltip: 'Salir al menu',
                          icon: Icons.logout,
                          onPressed: _salirAlMenu,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_alertaParticipantesRemotos != null)
                  Positioned(
                    top: 130,
                    left: 280,
                    right: 280,
                    child: PointerInterceptor(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ForColors.dangerPanel,
                          borderRadius: BorderRadius.circular(ForRadii.panel),
                          border: Border.all(
                            color: ForColors.dangerBorder,
                            width: 1.4,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: ForColors.shadow,
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: ForColors.goldPale,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Jugadores desconectados',
                                    style: ForTypography.alertTitle,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _alertaParticipantesRemotos!,
                                    style: ForTypography.alertBody,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Panel inferior izquierdo con todos los jugadores
                Positioned(
                  bottom: 30,
                  left: 20,
                  child: PointerInterceptor(
                    child: SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: _game.players
                            .map(
                              (player) => Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: _buildPlayerInfoCard(player),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),

                // Cabecera de era centrada sobre el mercado
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: PointerInterceptor(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: ForColors.panelDark,
                          borderRadius: BorderRadius.circular(ForRadii.panel),
                          border: Border.all(color: ForColors.gold, width: 1),
                        ),
                        child: Text(
                          'ERA ${_game.eraActual.name} • Cartas restantes: ${_game.mazos[_game.eraActual]?.length ?? 0}',
                          style: ForTypography.panelTitle.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Mercado superior centrado
                Positioned(
                  top: 62,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: PointerInterceptor(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ForColors.overlay,
                          borderRadius: BorderRadius.circular(ForRadii.panel),
                          border: Border.all(color: ForColors.borderMuted),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(deedMarketTags.length, (
                            index,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: TextButton(
                                onPressed:
                                    _game.mercado.isEmpty ||
                                        _turnoBloqueadoPorRemoto ||
                                        _interaccionBloqueadaLocalmente
                                    ? null
                                    : () async {
                                        bool compraRealizada;
                                        if (_modoRemotoActivo) {
                                          compraRealizada =
                                              await _sesionRemota
                                                  .comprarParcela(index);
                                        } else {
                                          try {
                                            compraRealizada =
                                                _game.comprarParcela(index);
                                          } on RuleError catch (e) {
                                            _mostrarMensaje(e.message);
                                            return;
                                          }
                                        }

                                        if (!compraRealizada) {
                                          return;
                                        }

                                        if (_modoRemotoActivo) {
                                          return;
                                        }

                                        setState(() {
                                          _sincronizarDeedMarketTags();
                                        });
                                        await _sincronizarEstadoJuego();
                                      },
                                style: ForButtonStyles.marketLot(),
                                child: Text(deedMarketTags[index]),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),

                if (_modoColocacionEdificio)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: PointerInterceptor(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: ForColors.panelDark,
                          borderRadius: BorderRadius.circular(ForRadii.panel),
                          border: Border.all(color: ForColors.gold, width: 1),
                        ),
                        child: Text(
                          'Colocando ${_edificioSeleccionado?.name ?? '-'} en ${_coordenadaSeleccionada ?? '-'} | Rotación: ${_rotacionSeleccionada + 1}/${_edificioSeleccionado == null ? 1 : _totalRotacionesVisuales(_edificioSeleccionado!)} | Rueda: cambiar rotación | Click: confirmar',
                          style: ForTypography.panelBody,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                if (_mostrarCatalogoEdificios)
                  Positioned.fill(
                    child: PointerInterceptor(
                      child: Container(
                        color: ForColors.overlay,
                        child: Center(
                          child: Container(
                            width: ForSizes.catalogWidth,
                            padding: const EdgeInsets.all(ForSpacing.lg),
                            decoration: BoxDecoration(
                              color: ForColors.panelMuted,
                              borderRadius: BorderRadius.circular(
                                ForRadii.panel,
                              ),
                              border: Border.all(color: ForColors.gold),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Construir edificio',
                                  style: ForTypography.panelTitle,
                                ),
                                const SizedBox(height: ForSpacing.md),
                                SizedBox(
                                  height: ForSizes.catalogHeight,
                                  child: ListView.builder(
                                    itemCount: _catalogItemCount,
                                    itemBuilder: _buildCatalogListItem,
                                  ),
                                ),
                                const SizedBox(height: ForSpacing.md),
                                OutlinedButton(
                                  onPressed: _cancelarColocacionEdificio,
                                  child: const Text('Cancelar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_coordenadasSeleccionAnclaje.isNotEmpty)
                  Positioned.fill(child: _buildSeleccionAnclajeOverlay()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
