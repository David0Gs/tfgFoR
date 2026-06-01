// Pantalla principal de partida. Coordina el motor de juego, el visor 3D,
// widgets de HUD, modo local/remoto, bots, guardado y resumen de eras.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:window_manager/window_manager.dart';
import '../../application/bots/local_bots.dart';
import '../../application/local_game/local_game.dart';
import 'package:for_core/core.dart';
import '../../infrastructure/audio/audio_service.dart';
import '../../infrastructure/sesion_remota.dart';
import '../../application_config.dart';
import '../../controlador_tablero.dart';
import '../../visor_3d/visor_3d_widget.dart';
import '../for_theme.dart';
import '../widgets/board_toolbar.dart';
import '../widgets/building_catalog_overlay.dart';
import '../widgets/deed_market_bar.dart';
import '../widgets/era_status_badge.dart';
import '../widgets/mensaje_tablero_content.dart';
import '../widgets/placement_hint_bar.dart';
import '../widgets/player_stats_dialog.dart';
import '../widgets/players_hud.dart';
import '../widgets/remote_leaderboard_dialog.dart';
import '../widgets/remote_participants_alert.dart';
import '../widgets/resumen_partida_dialog.dart';
import '../widgets/seleccion_anclaje_overlay.dart';
import '../widgets/seleccion_jugadores_local.dart';

/// Pantalla principal del tablero de juego.
///
/// Contiene el visor 3D y todos los controles de partida.
class PantallaTablero extends StatefulWidget {
  const PantallaTablero({
    this.initialPlayerCount = 2,
    this.initialLocalGameConfiguration,
    this.initialGame,
    this.initialRemoteSession,
    required this.onGuardarPartida,
    required this.onSalirAlMenu,
    super.key,
  });

  final int initialPlayerCount;
  final LocalGameConfiguration? initialLocalGameConfiguration;
  final Juego? initialGame;
  final SesionRemotaController? initialRemoteSession;
  final Future<void> Function(String jsonString) onGuardarPartida;
  final void Function(BuildContext context) onSalirAlMenu;

  @override
  State<PantallaTablero> createState() => _PantallaTableroState();
}

/// Extrae una coordenada de tablero desde el id de un objeto 3D clicado.
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

/// Extrae coordenadas ocupadas desde el id de un edificio construido.
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

/// Estado principal de la pantalla de tablero.
class _PantallaTableroState extends State<PantallaTablero> {
  static const String _mensajeSinSustitucionDisponible =
      'No puedes sustituir ese edificio: no hay ningun edificio disponible que pueda ocupar mas parcelas.';
  static const String _assetGifSinSustitucion = 'assets/pics/ahahah.gif';

  final TableroController _tableController = TableroController();
  late final SesionRemotaController _sesionRemota;
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

  /// Devuelve el asset GLB correspondiente a un edificio.
  String _assetParaBuilding(Edificio building) {
    return 'assets/models/building${building.id}.glb';
  }

  /// Devuelve la miniatura de video correspondiente a un edificio.
  String _thumbnailParaBuilding(Edificio building) {
    return 'assets/thumbnails/thumbnail${building.id}.mp4';
  }

  /// Devuelve el modelo de tablero adecuado al numero de jugadores.
  String get _modeloTableroActual {
    return boardModelPathForPlayerCount(_game.numeroJugadores);
  }

  /// Indica si el tablero se esta mostrando en una plataforma movil.
  bool get _esPlataformaMovil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Usa la UI compacta tambien en web cuando el viewport corresponde a movil
  /// o tablet. En escritorio web, reducir mucho la ventana activa el mismo
  /// layout responsive, lo que evita solapes.
  bool _usarLayoutMovil(BuildContext context) {
    if (_esPlataformaMovil) {
      return true;
    }
    if (!kIsWeb) {
      return false;
    }

    final Size size = MediaQuery.sizeOf(context);
    return size.width < 900;
  }

  /// Inicializa partida, controlador remoto, visor y turnos automaticos.
  @override
  void initState() {
    super.initState();
    if (_esPlataformaMovil) {
      unawaited(
        SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
    }
    if (!kIsWeb && ApplicationConfig.isDesktopPlatform) {
      unawaited(
        windowManager.setMinimumSize(ApplicationConfig.boardMinimumSize),
      );
    }
    _sesionRemota = widget.initialRemoteSession ?? SesionRemotaController();
    _game =
        widget.initialGame ??
        _sesionRemota.ultimoSnapshot ??
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
      if (!_modoRemotoActivo && urlInicial != null && aliasInicial != null) {
        _conectarSesionRemota(urlInicial, alias: aliasInicial, silent: true);
      } else {
        unawaited(_programarTurnosBotSiProcede());
      }
    });
    debugPrint("Inicializando aplicacion: Foundations of Rome");
  }

  /// Libera controladores y restaura tamaño minimo de ventana al salir.
  @override
  void dispose() {
    if (_esPlataformaMovil) {
      unawaited(
        SystemChrome.setPreferredOrientations(DeviceOrientation.values),
      );
    }
    if (!kIsWeb && ApplicationConfig.isDesktopPlatform) {
      unawaited(
        windowManager.setMinimumSize(ApplicationConfig.menuMinimumSize),
      );
    }
    _tableController.ocultarPreviewEdificio();
    _tableController.registrarClickObjeto(null);
    _sesionRemota.removeListener(_manejarCambiosSesionRemota);
    unawaited(_sesionRemota.cerrar());
    super.dispose();
  }

  /// Indica si el tablero esta conectado a una partida remota.
  bool get _modoRemotoActivo => _sesionRemota.modoRemotoActivo;

  /// Bloquea acciones cuando en remoto no es el turno de este cliente.
  bool get _turnoBloqueadoPorRemoto {
    if (!_modoRemotoActivo) {
      return false;
    }
    if (!_sesionRemota.conectado) {
      return true;
    }
    return _sesionRemota.playerId != _game.indiceJugadorActual;
  }

  /// Indica si el jugador actual es bot en una partida local.
  bool get _turnoBotLocalActivo => !_modoRemotoActivo && _jugadorActual.isBot;

  /// Indica si la UI debe impedir acciones por carga o turno de bot.
  bool get _interaccionBloqueadaLocalmente =>
      !_modoRemotoActivo &&
      (!_tablero3DListo || _turnoBotLocalActivo || _botTurnRunner.isProcessing);

  /// Mensaje de presencia remota que debe mostrarse sobre el tablero.
  String? get _alertaParticipantesRemotos => _sesionRemota.alertaParticipantes;

  /// Reacciona a snapshots, resumenes, presencia y errores remotos.
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

  /// Conecta la pantalla a una sesion remota ya existente o nueva.
  Future<void> _conectarSesionRemota(
    String url, {
    required String alias,
    String? roomAlias,
    bool createRoom = false,
    int? players,
    bool silent = false,
  }) async {
    try {
      await _sesionRemota.unirse(
        url,
        playerName: alias,
        roomAlias: roomAlias,
        createRoom: createRoom,
        players: players,
      );
      if (!silent) {
        final String roomText = roomAlias == null || roomAlias.isEmpty
            ? url
            : 'sala $roomAlias';
        _mostrarMensajeDiferido('Conectado a $roomText con alias $alias.');
      }
    } catch (e) {
      // El listener de la sesión remota ya publica el error y evita duplicados.
    }
  }

  /// Muestra el leaderboard remoto usando la sesion WebSocket activa.
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
        return AnimatedBuilder(
          animation: _sesionRemota,
          builder: (BuildContext context, Widget? child) {
            return RemoteLeaderboardDialog(
              entries: _sesionRemota.leaderboard,
              loading: _sesionRemota.cargandoLeaderboard,
              error: _sesionRemota.ultimoErrorLeaderboard,
              onReload: _sesionRemota.cargandoLeaderboard
                  ? null
                  : () {
                      unawaited(_sesionRemota.solicitarLeaderboard());
                    },
            );
          },
        );
      },
    );
  }

  /// Comprueba si el jugador puede ejecutar una accion en este momento.
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

  /// Sincroniza los textos del mercado de parcelas con el estado del juego.
  void _sincronizarDeedMarketTags() {
    deedMarketTags = List<String>.generate(_game.mercado.length, (index) {
      final CartaEscritura carta = _game.mercado[index];
      return '${carta.coord} (Coste: ${costes[index]})';
    });

    if (deedMarketTags.isEmpty) {
      deedMarketTags = const ['Mercado vacío'];
    }
  }

  /// Sincroniza marcadores y edificios del estado de juego con la escena 3D.
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

  /// Lanza turnos de bots locales si el jugador actual no es humano.
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

  /// Refresca mercado, escena 3D, resumenes y posibles turnos de bots.
  Future<void> _sincronizarEstadoJuego({
    bool programarBots = true,
    Set<String> edificiosOcultos = const <String>{},
  }) async {
    if (!mounted) return;
    final Stopwatch stopwatch = Stopwatch()..start();
    setState(() {
      _sincronizarDeedMarketTags();
    });
    await _sincronizarMarcadores3D(edificiosOcultos: edificiosOcultos);
    await _mostrarResumenPendienteSiExiste();
    if (programarBots) {
      await _programarTurnosBotSiProcede();
    }
    stopwatch.stop();
    debugPrint(
      '[FOR PERF] sync state total=${stopwatch.elapsedMilliseconds}ms '
      'player=${_game.indiceJugadorActual} era=${_game.eraActual.name} '
      'built=${_contarEdificiosUnicosEnTablero()} '
      'lots=${_game.players.fold<int>(0, (total, player) => total + player.lots.length)}',
    );
  }

  int _contarEdificiosUnicosEnTablero() {
    final Set<Propiedad> edificiosUnicos = <Propiedad>{};
    edificiosUnicos.addAll(_game.edificios.values);
    return edificiosUnicos.length;
  }

  /// Ejecuta la accion de ingresos en local o la envia al servidor remoto.
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

  /// Compra una parcela del mercado en local o remoto.
  Future<void> _comprarParcelaMercado(int index) async {
    bool compraRealizada;
    if (_modoRemotoActivo) {
      compraRealizada = await _sesionRemota.comprarParcela(index);
    } else {
      try {
        compraRealizada = _game.comprarParcela(index);
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
  }

  /// Muestra un SnackBar con mensaje contextual del tablero.
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
          content: MensajeTableroContent(
            mensaje: mensaje,
            mensajeConGif: _mensajeSinSustitucionDisponible,
            gifAsset: _assetGifSinSustitucion,
          ),
          duration: duration ?? const Duration(seconds: 4),
        ),
      );
  }

  /// Programa un mensaje para despues del frame actual.
  void _mostrarMensajeDiferido(String mensaje) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mostrarMensaje(mensaje);
    });
  }

  /// Limpia seleccion, catalogo y preview de colocacion.
  void _restablecerEstadoInteractivo() {
    _coordenadasSeleccionAnclaje = const <String>[];
    _mostrarCatalogoEdificios = false;
    _modoColocacionEdificio = false;
    _coordenadaSeleccionada = null;
    _rotacionSeleccionada = 0;
    _edificioSeleccionado = null;
    _edificioDesdeMonumentos = false;
  }

  /// Sustituye el juego actual por un snapshot nuevo y sincroniza la escena.
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

  /// Marca el tablero 3D como listo cuando el modelo principal ha cargado.
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

  /// Guarda la partida local actual como JSON.
  Future<void> _guardarPartida() async {
    try {
      await widget.onGuardarPartida(_game.toJsonString());
      _mostrarMensaje('Partida guardada correctamente.');
    } catch (e) {
      _mostrarMensaje('No se pudo guardar la partida: $e');
    }
  }

  /// Sale al menu cerrando la preview 3D antes de cambiar de pantalla.
  Future<void> _salirAlMenu() async {
    await _tableController.ocultarPreviewEdificio();

    if (!mounted) {
      return;
    }
    widget.onSalirAlMenu(context);
  }

  /// Jugador cuyo turno se esta resolviendo.
  Jugador get _jugadorActual => _game.players[_game.indiceJugadorActual];

  /// Color visual asociado a un jugador.
  Color _colorJugador(int playerId) {
    return ForColors.getPlayerColor(playerId);
  }

  /// Numero de rotaciones visuales disponibles para un edificio.
  int _totalRotacionesVisuales(Edificio building) {
    final bool esUnaParcela =
        building.rotations.length == 1 && building.rotations.first.length == 1;
    return esUnaParcela ? 4 : building.rotations.length;
  }

  /// Compara coordenadas de tablero por columna y fila.
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

  /// Indica si existe algun edificio que pueda colocarse en una coordenada.
  bool _hayEdificiosColocablesEn(String coord) {
    for (final Edificio building in _jugadorActual.availableBuildings) {
      if (_game.puedeColocarEdificio(coord, building, isFromMonument: false) ==
          null) {
        return true;
      }
    }

    for (final Edificio building in _game.monumentosDisponibles) {
      if (_game.puedeColocarEdificio(coord, building, isFromMonument: true) ==
          null) {
        return true;
      }
    }

    return false;
  }

  /// Indica si existe alguna coordenada con edificios colocables.
  bool _hayEdificiosColocablesEnAlguna(Iterable<String> coords) {
    return coords.any(_hayEdificiosColocablesEn);
  }

  /// Muestra el mensaje especial cuando no se puede sustituir un edificio.
  void _mostrarMensajeSinSustitucionDisponible() {
    _mostrarMensaje(_mensajeSinSustitucionDisponible);
  }

  /// Abre el selector de anclaje para elegir una coordenada ocupada.
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

  /// Confirma el anclaje elegido y abre el catalogo de edificios.
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

  /// Cancela el flujo de seleccion de anclaje.
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

  /// Procesa clicks sobre solares, marcadores o edificios del visor 3D.
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
      final List<String> ownedCoords =
          occupiedCoordsFromBuiltObjectId(objectId)
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

    unawaited(_tableController.centrarCamaraEnCasilla(coord));

    setState(() {
      _coordenadaSeleccionada = coord;
      _mostrarCatalogoEdificios = true;
      _rotacionSeleccionada = 0;
    });
  }

  /// Selecciona un edificio y muestra su preview sobre la coordenada activa.
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

    await _actualizarEdificiosOcultosPorPreview();
    await _tableController.mostrarPreviewEdificio(
      coord,
      modelPath: _assetParaBuilding(building),
      templateId: building.id,
      rotationIndex: _rotacionSeleccionada,
    );
    await _actualizarEdificiosOcultosPorPreview();
  }

  /// Oculta temporalmente edificios que quedan bajo la preview seleccionada.
  Future<void> _actualizarEdificiosOcultosPorPreview() async {
    final String? coord = _coordenadaSeleccionada;
    final Edificio? building = _edificioSeleccionado;
    if (!_modoColocacionEdificio || coord == null || building == null) {
      await _tableController.restaurarEdificiosOcultosPorPreview();
      return;
    }

    try {
      final Set<String> targetCoords = <String>{
        coord,
        ..._game.targetCoordsForPlacement(
          coord,
          building,
          _rotacionSeleccionada,
        ),
      };
      await _tableController.ocultarEdificiosEnCoordenadas(targetCoords);
    } on RuleError {
      await _tableController.ocultarEdificiosEnCoordenadas(<String>{coord});
    }
  }

  /// Rota la preview del edificio usando la rueda del raton.
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

  /// Ejecuta una construccion manteniendo animacion y sincronizacion visual.
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

  /// Confirma la colocacion elegida por el jugador.
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

  /// Ejecuta una accion de bot y actualiza la escena con feedback visual.
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

  /// Cancela el flujo de colocacion y restaura la escena.
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

  /// Gestiona clicks del raton mientras hay una preview de edificio activa.
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

  /// Gestiona la rueda del raton para rotar una preview activa.
  void _manejarRuedaColocacion(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _modoColocacionEdificio) {
      unawaited(_rotarPreviewPorRueda(event.scrollDelta.dy > 0));
    }
  }

  /// Muestra un resumen pendiente generado por el motor si existe.
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

  /// Abre el dialogo de resumen de era o final de partida.
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
        return ResumenPartidaDialog(
          title: resumen['title'] as String,
          lines: lineas,
        );
      },
    );

    _mostrandoResumen = false;
    if (confirmado != true) return;
  }

  /// Indica si el panel de otro jugador puede consultarse ahora.
  bool _puedeConsultarPanelJugador(Jugador player) {
    return player.id != _jugadorActual.id && !_jugadorActual.isBot;
  }

  /// Cuenta edificios unicos construidos por un jugador.
  int _contarEdificiosJugador(Jugador player) {
    final Set<Propiedad> edificiosUnicos = <Propiedad>{
      for (final Propiedad propiedad in _game.edificios.values)
        if (propiedad.ownerId == player.id) propiedad,
    };
    return edificiosUnicos.length;
  }

  /// Muestra el dialogo de estadisticas detalladas de un jugador.
  Future<void> _mostrarEstadisticasJugador(Jugador player) async {
    if (!mounted ||
        (!_usarLayoutMovil(context) && !_puedeConsultarPanelJugador(player))) {
      return;
    }

    final int edificiosConstruidos = _contarEdificiosJugador(player);

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) {
        return PlayerStatsDialog(
          player: player,
          color: _colorJugador(player.id),
          builtBuildings: edificiosConstruidos,
        );
      },
    );
  }

  /// Construye toda la interfaz del tablero.
  @override
  Widget build(BuildContext context) {
    final bool layoutMovil = _usarLayoutMovil(context);
    final bool bloqueandoAccionesPorColocacion = _modoColocacionEdificio;

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

                // Boton de controles.
                Positioned(
                  bottom: 30,
                  right: layoutMovil ? 10 : 20,
                  child: BoardToolbar(
                    isMutedListenable: AudioService.instance.isMuted,
                    remoteModeActive: _modoRemotoActivo,
                    leaderboardEnabled: _sesionRemota.conectado,
                    incomeEnabled:
                        !_turnoBloqueadoPorRemoto &&
                        !_interaccionBloqueadaLocalmente,
                    saveEnabled: !_modoRemotoActivo,
                    onToggleMuted: AudioService.instance.toggleMuted,
                    onResetCamera: () => _tableController.resetearVista(),
                    onShowLeaderboard: _mostrarLeaderboardRemoto,
                    onIncome: _ejecutarIngreso,
                    onSave: _guardarPartida,
                    onExit: _salirAlMenu,
                    compact: layoutMovil,
                    actionsLocked: bloqueandoAccionesPorColocacion,
                    rotationEnabled:
                        _modoColocacionEdificio &&
                        _edificioSeleccionado != null,
                    onRotate: layoutMovil
                        ? () => unawaited(_rotarPreviewPorRueda(true))
                        : null,
                    cancelPlacementEnabled:
                        _modoColocacionEdificio &&
                        _edificioSeleccionado != null,
                    onCancelPlacement: layoutMovil
                        ? () => unawaited(_cancelarColocacionEdificio())
                        : null,
                  ),
                ),

                if (_alertaParticipantesRemotos != null)
                  Positioned(
                    top: 130,
                    left: 280,
                    right: 280,
                    child: RemoteParticipantsAlert(
                      message: _alertaParticipantesRemotos!,
                    ),
                  ),

                // Panel inferior izquierdo con todos los jugadores.
                Positioned(
                  bottom: 30,
                  left: layoutMovil ? 10 : 20,
                  child: PlayersHud(
                    players: _game.players,
                    currentPlayerId: _game.indiceJugadorActual,
                    colorForPlayer: _colorJugador,
                    isConsultable: bloqueandoAccionesPorColocacion
                        ? (_) => false
                        : layoutMovil
                        ? (_) => true
                        : _puedeConsultarPanelJugador,
                    onPlayerTap: _mostrarEstadisticasJugador,
                    compact: layoutMovil,
                  ),
                ),

                // Cabecera de era centrada sobre el mercado.
                Positioned(
                  top: layoutMovil ? 12 : 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: EraStatusBadge(
                      eraName: _game.eraActual.name,
                      remainingCards: _game.mazos[_game.eraActual]?.length ?? 0,
                      roomAlias: _sesionRemota.modoRemotoActivo
                          ? _sesionRemota.roomAlias
                          : null,
                      compact: layoutMovil,
                    ),
                  ),
                ),

                // Mercado superior centrado.
                Positioned(
                  top: layoutMovil ? 42 : 62,
                  left: layoutMovil ? 90 : 0,
                  right: layoutMovil ? 90 : 0,
                  child: layoutMovil
                      ? DeedMarketBar(
                          labels: deedMarketTags,
                          enabled:
                              _game.mercado.isNotEmpty &&
                              !bloqueandoAccionesPorColocacion &&
                              !_turnoBloqueadoPorRemoto &&
                              !_interaccionBloqueadaLocalmente,
                          onBuy: _comprarParcelaMercado,
                          compact: true,
                        )
                      : Center(
                          child: DeedMarketBar(
                            labels: deedMarketTags,
                            enabled:
                                _game.mercado.isNotEmpty &&
                                !bloqueandoAccionesPorColocacion &&
                                !_turnoBloqueadoPorRemoto &&
                                !_interaccionBloqueadaLocalmente,
                            onBuy: _comprarParcelaMercado,
                          ),
                        ),
                ),

                if (_modoColocacionEdificio)
                  Positioned(
                    bottom: layoutMovil ? 8 : 20,
                    left: layoutMovil ? 116 : 20,
                    right: layoutMovil ? 54 : 20,
                    child: PlacementHintBar(
                      buildingName: _edificioSeleccionado?.name ?? '-',
                      coord: _coordenadaSeleccionada ?? '-',
                      rotationIndex: _rotacionSeleccionada,
                      totalRotations: _edificioSeleccionado == null
                          ? 1
                          : _totalRotacionesVisuales(_edificioSeleccionado!),
                    ),
                  ),
                if (_mostrarCatalogoEdificios)
                  Positioned.fill(
                    child: BuildingCatalogOverlay(
                      playerBuildings: _jugadorActual.availableBuildings,
                      monuments: _game.monumentosDisponibles,
                      validatePlacement:
                          (Edificio building, {required bool isFromMonument}) {
                            final String? coord = _coordenadaSeleccionada;
                            if (coord == null) {
                              return 'Selecciona una parcela primero';
                            }
                            return _game.puedeColocarEdificio(
                              coord,
                              building,
                              isFromMonument: isFromMonument,
                            );
                          },
                      monumentRequirementSummary:
                          _game.monumentRequirementSummary,
                      thumbnailForBuilding: _thumbnailParaBuilding,
                      onSelect:
                          (Edificio building, {required bool fromMonument}) =>
                              _seleccionarEdificio(
                                building,
                                desdeMonumentos: fromMonument,
                              ),
                      onDisabledTap: _mostrarMensaje,
                      onCancel: _cancelarColocacionEdificio,
                      compact: layoutMovil,
                    ),
                  ),
                if (_coordenadasSeleccionAnclaje.isNotEmpty)
                  Positioned.fill(
                    child: SeleccionAnclajeOverlay(
                      coordenadas: _coordenadasSeleccionAnclaje,
                      onSeleccionar: _confirmarSeleccionAnclaje,
                      onCancelar: _cancelarSeleccionAnclaje,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
