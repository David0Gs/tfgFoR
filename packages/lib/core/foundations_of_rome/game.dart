// ignore_for_file: avoid_print

// Motor principal de reglas de Foundations of Rome. Mantiene el estado de la
// partida, valida acciones, avanza turnos/eras, calcula puntuaciones y permite
// serializar o reconstruir partidas.

import 'dart:convert';

import 'building_catalog.dart';
import 'entities/building.dart';
import 'entities/deed_card.dart';
import 'entities/player.dart';
import 'entities/property.dart';
import 'errors/rule_error.dart';
import 'value_objects/building_type.dart';
import 'value_objects/era.dart';
import 'value_objects/player_color.dart';
import 'value_objects/player_kind.dart';

/// Resultado interno de validar una construccion.
class _ValidacionConstruccion {
  _ValidacionConstruccion({
    required this.player,
    required this.targetCoords,
    required this.buildingsToRemove,
  });

  final Jugador player;
  final List<String> targetCoords;
  final List<Propiedad> buildingsToRemove;
}

/// Devuelve la poblacion que aporta un edificio residencial.
int _obtenerPoblacionEdificio(Edificio template) {
  switch (template.id) {
    case "Domus I":
    case "Domus II":
      return 1;
    case "DomusMaximaI":
    case "DomusMaximaII":
      return 2;
    case "InsulaL":
    case "Insula":
      return 4;
    case "GranInsulaCuadrada":
    case "GranInsulaRecta":
      return 6;
    default:
      return 0;
  }
}

/// Estado completo y reglas de una partida.
class Juego {
  final int numeroJugadores;
  final List<TipoJugador>? _playerKinds;
  late int tamanoTablero;
  final List<Jugador> players = [];
  int indiceJugadorActual = 0;
  Era eraActual = Era.I;
  bool rondaFinalEraIIIActiva = false;
  int turnosRestantesRondaFinalEraIII = 0;
  bool partidaFinalizada = false;
  String? tituloResumenPendiente;
  List<String> lineasResumenPendiente = <String>[];
  bool resumenPendienteEsFinal = false;
  bool avanzarAEraSiguienteDespuesDeResumen = false;

  final Map<String, int> propietariosLotes = {};
  final Map<String, Propiedad> edificios = {};
  final Map<Era, List<CartaEscritura>> mazos = {
    Era.I: [],
    Era.II: [],
    Era.III: [],
  };
  final List<CartaEscritura> mercado = [];
  final List<Edificio> monumentosDisponibles = [];

  List<String> coloresJugadores = [
    ColorJugador.rojo,
    ColorJugador.verde,
    ColorJugador.amarillo,
    ColorJugador.azul,
    ColorJugador.magenta,
  ];

  /// Consume y limpia el resumen pendiente para que la UI lo muestre una vez.
  Map<String, dynamic>? consumirResumenPendiente() {
    if (tituloResumenPendiente == null) {
      return null;
    }

    final Map<String, dynamic> resumen = {
      'title': tituloResumenPendiente!,
      'lines': List<String>.from(lineasResumenPendiente),
      'isFinal': resumenPendienteEsFinal,
    };

    tituloResumenPendiente = null;
    lineasResumenPendiente = <String>[];
    resumenPendienteEsFinal = false;
    return resumen;
  }

  /// Registra un resumen de era o final de partida pendiente de mostrar.
  void registrarResumenPendiente(
    String title,
    List<String> lines, {
    bool isFinal = false,
    bool advanceToNextEra = false,
  }) {
    tituloResumenPendiente = title;
    lineasResumenPendiente = List<String>.from(lines);
    resumenPendienteEsFinal = isFinal;
    avanzarAEraSiguienteDespuesDeResumen = advanceToNextEra;
  }

  /// Confirma un resumen mostrado y avanza de era si estaba pendiente.
  void confirmarResumenPendiente() {
    if (avanzarAEraSiguienteDespuesDeResumen &&
        !partidaFinalizada &&
        eraActual != Era.III) {
      eraActual = Era.values[eraActual.index + 1];
      _refrescarMercado();
      print('\n--- COMIENZA LA ERA ${eraActual.name} ---');
    }
    avanzarAEraSiguienteDespuesDeResumen = false;
  }

  /// Crea una partida nueva con numero de jugadores y tipos opcionales.
  Juego(this.numeroJugadores, {List<TipoJugador>? playerKinds})
    : _playerKinds = playerKinds == null
          ? null
          : List<TipoJugador>.unmodifiable(playerKinds) {
    if (_playerKinds != null && _playerKinds.length != numeroJugadores) {
      throw ArgumentError.value(
        playerKinds,
        'playerKinds',
        'El numero de tipos de jugador debe coincidir con playerCount.',
      );
    }
    _configurarTablero();
    _configurarJugadores();
    _configurarMonumentos();
    _configurarMazos();
    _refrescarMercado();
  }

  /// Configura el tamaño de tablero segun el numero de jugadores.
  void _configurarTablero() {
    if (numeroJugadores == 2) {
      tamanoTablero = 7;
    } else if (numeroJugadores == 3) {
      tamanoTablero = 8;
    } else if (numeroJugadores == 4) {
      tamanoTablero = 9;
    } else {
      tamanoTablero = 10;
    }
  }

  /// Crea los jugadores iniciales y sus bandejas de edificios.
  void _configurarJugadores() {
    for (int i = 0; i < numeroJugadores; i++) {
      final TipoJugador kind = _playerKinds?[i] ?? TipoJugador.human;
      Jugador p = Jugador(i, 'Arquitecto ${i + 1}', 5 + i, kind: kind);
      // La bandeja inicial contiene solo edificios normales; los monumentos
      // viven en una reserva comun.
      p.availableBuildings.addAll(
        catalogoEdificios.where((b) => !conjuntoIdsMonumentos.contains(b.id)),
      );
      players.add(p);
    }
    _actualizarMarcadoresPoblacion();
  }

  /// Selecciona los monumentos disponibles para la partida.
  void _configurarMonumentos() {
    List<Edificio> allMonuments = catalogoEdificios
        .where((t) => conjuntoIdsMonumentos.contains(t.id))
        .toList();
    allMonuments.shuffle();
    monumentosDisponibles.addAll(allMonuments.take(numeroJugadores + 3));
  }

  /// Recalcula los marcadores de poblacion de todos los jugadores.
  void _actualizarMarcadoresPoblacion() {
    final Map<int, int> populationByPlayer = <int, int>{};
    for (final Propiedad building in edificios.values) {
      if (building.type != TipoEdificio.residential) {
        continue;
      }

      final int population = _obtenerPoblacionEdificio(building.template);
      populationByPlayer.update(
        building.ownerId,
        (int total) => total + population,
        ifAbsent: () => population,
      );
    }

    for (final Jugador player in players) {
      player.populationTrack = populationByPlayer[player.id] ?? 0;
    }
  }

  /// Devuelve el color ANSI de un jugador para la version CLI.
  String _obtenerColor(int playerId) {
    switch (playerId) {
      case 0:
        return ColorJugador.rojo;
      case 1:
        return ColorJugador.verde;
      case 2:
        return ColorJugador.amarillo;
      case 3:
        return ColorJugador.azul;
      case 4:
        return ColorJugador.magenta;
      default:
        return ColorJugador.reset;
    }
  }

  /// Divide todas las coordenadas del tablero en mazos por era.
  void dividirCartasPorEras(List<String> allTiles) {
    int totalTiles = allTiles.length;
    int eraSize = (totalTiles / 3).ceil();

    allTiles
        .sublist(0, eraSize)
        .forEach((tile) => mazos[Era.I]!.add(CartaEscritura(tile, Era.I)));
    allTiles
        .sublist(eraSize, eraSize * 2)
        .forEach((tile) => mazos[Era.II]!.add(CartaEscritura(tile, Era.II)));
    allTiles
        .sublist(eraSize * 2)
        .forEach((tile) => mazos[Era.III]!.add(CartaEscritura(tile, Era.III)));
  }

  /// Crea los mazos de escrituras iniciales.
  void _configurarMazos() {
    var allTiles = <String>[];
    for (int r = 1; r <= tamanoTablero; r++) {
      for (int c = 0; c < tamanoTablero; c++) {
        String coord = '${String.fromCharCode(65 + c)}$r';
        allTiles.add(coord);
      }
    }
    allTiles.shuffle();
    dividirCartasPorEras(allTiles);
    // print('Decks preparados:');
    // decks.forEach((era, cards) {
    //   print('  ${era.name}: ${cards.length} cartas');
    //   for (var card in cards) {
    //     print('    - ${card.coord}');
    //   }
    // });
  }

  /// Rellena el mercado con cartas de la era actual.
  void _refrescarMercado() {
    while (mercado.length < 6 && mazos[eraActual]!.isNotEmpty) {
      mercado.add(mazos[eraActual]!.removeLast());
    }
  }

  /// Imprime el estado resumido de la partida en consola.
  void imprimirEstado() {
    Jugador p = players[indiceJugadorActual];
    print('\n=======================================');
    print('TURNO: ${_obtenerColor(p.id)}${p.name}${ColorJugador.reset}');
    print(
      'Monedas: ${p.coins} | Marcadores: [${p.availableMarkers}/8] | Gloria: ${p.glory} | Población: ${p.populationTrack}',
    );
    print('Parcelas reservadas: ${p.lots.length}');
    print(
      'Era actual: ${eraActual.name} Cartas restantes: ${mazos[eraActual]!.length}',
    );
    if (rondaFinalEraIIIActiva) {
      print(
        'Ronda final de Era III activa: quedan $turnosRestantesRondaFinalEraIII turno(s) adicional(es).',
      );
    }

    List<String> emptyLots = [];
    List<String> builtBuildings = [];
    Set<Propiedad> countedBuildings = {};

    int compareCoords(String a, String b) {
      int colA = a.codeUnitAt(0);
      int colB = b.codeUnitAt(0);
      if (colA != colB) return colA.compareTo(colB);
      int rowA = int.parse(a.substring(1));
      int rowB = int.parse(b.substring(1));
      return rowA.compareTo(rowB);
    }

    for (String coord in p.lots) {
      if (edificios.containsKey(coord)) {
        Propiedad b = edificios[coord]!;
        if (!countedBuildings.contains(b)) {
          countedBuildings.add(b);
          List<String> occupied = List<String>.from(b.occupiedCoords)
            ..sort(compareCoords);
          String typeTag = nombreTipoEdificio(b.type);
          builtBuildings.add(
            '${b.template.name}[$typeTag${occupied.length}] -> ${occupied.join(", ")}',
          );
        }
      } else {
        emptyLots.add(coord);
      }
    }

    emptyLots.sort(compareCoords);

    print(
      'Parcelas con Marcador (Libres): ${emptyLots.isEmpty ? "Ninguna" : emptyLots.join(", ")}',
    );
    print(
      'Edificios del jugador: ${builtBuildings.isEmpty ? "Ninguno" : builtBuildings.join(" | ")}',
    );
    print(
      'Monumentos disponibles: ${monumentosDisponibles.isEmpty ? "Ninguno" : monumentosDisponibles.map((m) => "${m.name} (${_monumentRequirementSummary(m.id)})").join(", ")}',
    );

    print('\nMercado (coste = posición):');
    for (int i = 0; i < mercado.length; i++) {
      print('  [$i] ${mercado[i].coord} (Coste: ${costes[i]})');
    }

    print('=======================================');
  }

  // ACCION A: INGRESOS.
  /// Ejecuta la accion de ingresos del jugador actual.
  void accionIngresos() {
    if (partidaFinalizada) {
      print('\n!! La partida ya ha terminado.');
      return;
    }

    Jugador p = players[indiceJugadorActual];
    int base = 5;
    int commBonus = 0;
    Set<Propiedad> countedCommercial = {};

    for (Propiedad b in edificios.values) {
      if (b.ownerId == p.id &&
          b.type == TipoEdificio.commercial &&
          !countedCommercial.contains(b)) {
        countedCommercial.add(b);
        switch (b.template.id) {
          case "PanaderiaI":
          case "PanaderiaII":
            commBonus += 1;
            break;
          case "AlfareriaI":
          case "AlfareriaII":
            commBonus += 1;
            break;
          case "ForoArtesanoL":
          case "ForoArtesano":
            commBonus += 2;
            break;
          case "FundicionRecta":
          case "FundicionCuadrada":
            commBonus += 3;
            break;
        }
      }
    }

    int monumentBonus = _calculateMonumentCoinBonus(p);

    p.coins += (base + commBonus + monumentBonus);
    print(
      '\n>> ${p.name} recauda ${base + commBonus + monumentBonus} denarios (Base: 5, Comercial: $commBonus, Monumentos: $monumentBonus).',
    );
    _endTurn();
  }

  // ACCION B: COMPRAR ESCRITURA.
  /// Compra una parcela del mercado para el jugador actual.
  bool comprarParcela(int index) {
    if (partidaFinalizada) {
      throw const RuleError('La partida ya ha terminado.');
    }

    if (mercado.isEmpty) {
      throw const RuleError('No quedan parcelas disponibles para comprar.');
    }
    if (index < 0 || index >= mercado.length) {
      throw const RuleError('Índice de parcela no válido.');
    }
    Jugador p = players[indiceJugadorActual];

    if (p.availableMarkers <= 0) {
      throw const RuleError(
        'No te quedan marcadores. Debes construir para liberar espacio.',
      );
    }

    int cost = costes[index];
    if (p.coins >= cost) {
      p.coins -= cost;
      CartaEscritura card = mercado.removeAt(index);

      p.lots.add(card.coord);
      p.availableMarkers--;
      propietariosLotes[card.coord] = p.id;

      print(
        '\n>> ${p.name} compra la parcela ${card.coord}. (Marcadores restantes: ${p.availableMarkers})',
      );
      _refrescarMercado();
      _endTurn();
      return true;
    }
    throw RuleError(
      'Monedas insuficientes. Necesitas $cost y tienes ${p.coins}.',
    );
  }

  // ACCION C: CONSTRUIR / SOBREESCRIBIR CON ROTACIONES.
  /// Valida una construccion y lanza RuleError si no es legal.
  void validarConstruccion(
    String originCoord,
    Edificio template,
    int rotationIdx,
    int buildingIdx,
    bool isFromMonument,
  ) {
    _resolveBuildValidation(
      originCoord,
      template,
      rotationIdx,
      buildingIdx,
      isFromMonument,
    );
  }

  /// Construye un edificio o monumento en el tablero.
  bool construir(
    String originCoord,
    Edificio template,
    int rotationIdx,
    int buildingIdx,
    bool isFromMonument,
  ) {
    final _ValidacionConstruccion validation = _resolveBuildValidation(
      originCoord,
      template,
      rotationIdx,
      buildingIdx,
      isFromMonument,
    );
    final Jugador p = validation.player;
    final List<String> targetCoords = validation.targetCoords;
    final List<Propiedad> buildingsToRemove = validation.buildingsToRemove;
    final Set<String> targetCoordSet = targetCoords.toSet();
    final Set<String> coordsWithBuildingBeforeRemoval = <String>{};
    for (final Propiedad oldB in buildingsToRemove) {
      coordsWithBuildingBeforeRemoval.addAll(oldB.occupiedCoords);
    }

    // Los edificios sustituidos se retiran antes de colocar el nuevo edificio.
    for (var oldB in buildingsToRemove) {
      // Se limpian las coordenadas que ocupaba el edificio anterior.
      for (var c in oldB.occupiedCoords) {
        edificios.remove(c);
        if (!targetCoordSet.contains(c)) {
          final int? markerOwnerId = propietariosLotes[c];
          if (markerOwnerId != null &&
              markerOwnerId >= 0 &&
              markerOwnerId < players.length) {
            players[markerOwnerId].availableMarkers--;
          }
        }
      }
      final bool wasMonument = conjuntoIdsMonumentos.contains(oldB.template.id);

      // Los monumentos retirados siempre vuelven a la bandeja comun.
      if (wasMonument) {
        monumentosDisponibles.add(oldB.template);
        print(
          '>> El monumento ${oldB.template.name} vuelve a la bandeja comun.',
        );
      } else if (oldB.ownerId == p.id) {
        p.availableBuildings.add(oldB.template);
        print(
          '>> El edificio ${oldB.template.name} vuelve a la bandeja de ${p.name}.',
        );
      } else {
        print('>> El edificio ${oldB.template.name} vuelve a la reserva.');
      }
    }

    // 4. Colocación del nuevo edificio y liberación de marcadores
    Propiedad placedBuilding = Propiedad(
      ownerId: p.id,
      template: template,
      occupiedCoords: targetCoords,
      rotationIndex: rotationIdx,
    );

    for (String coord in targetCoords) {
      // Al colocar la pieza física, recuperamos el marcador de lote para la reserva
      // Solo sumamos si no había un edificio previo en esa parcela.
      if (propietariosLotes.containsKey(coord) &&
          !coordsWithBuildingBeforeRemoval.contains(coord)) {
        p.availableMarkers++;
      }

      edificios[coord] = placedBuilding;
    }

    // Remover el edificio usado de la bandeja correspondiente
    if (isFromMonument) {
      monumentosDisponibles.removeAt(buildingIdx);
    } else {
      p.availableBuildings.removeAt(buildingIdx);
    }

    // Actualizar Track de Población dinámicamente
    _actualizarMarcadoresPoblacion();

    // Aplicar beneficios inmediatos de monumentos
    if (isFromMonument) {
      _applyMonumentBenefits(p, template, targetCoords);
    }

    print(
      '\n>> ${p.name} construyó ${template.name} en ${targetCoords.join(", ")}.',
    );
    _endTurn();
    return true;
  }

  /// Resuelve la validacion completa y devuelve datos para construir.
  _ValidacionConstruccion _resolveBuildValidation(
    String originCoord,
    Edificio template,
    int rotationIdx,
    int buildingIdx,
    bool isFromMonument,
  ) {
    if (partidaFinalizada) {
      throw const RuleError('La partida ya ha terminado.');
    }

    final Jugador p = players[indiceJugadorActual];
    final String normalizedOrigin = originCoord.toUpperCase().trim();
    final List<Edificio> sourceBuildings = isFromMonument
        ? monumentosDisponibles
        : p.availableBuildings;

    if (buildingIdx < 0 || buildingIdx >= sourceBuildings.length) {
      throw RuleError(
        isFromMonument
            ? 'El monumento seleccionado ya no esta disponible.'
            : 'El edificio seleccionado ya no esta disponible.',
      );
    }

    if (sourceBuildings[buildingIdx].id != template.id) {
      throw RuleError(
        isFromMonument
            ? 'El monumento seleccionado ya no coincide con la bandeja actual.'
            : 'El edificio seleccionado ya no coincide con tu bandeja actual.',
      );
    }

    if (!isCoordOnBoard(normalizedOrigin)) {
      throw const RuleError(
        'Coordenada de origen no valida o fuera del tablero.',
      );
    }

    if (!p.lots.contains(normalizedOrigin)) {
      throw const RuleError(
        'Debes elegir una parcela del tablero que te pertenezca para iniciar la construccion.',
      );
    }

    if (isFromMonument) {
      _validateMonumentRequirements(p, template);
    }

    final List<String> targetCoords = _construirCoordenadasObjetivo(
      normalizedOrigin,
      template,
      rotationIdx,
    );

    for (final String coord in targetCoords) {
      if (!p.lots.contains(coord)) {
        throw RuleError('No posees derechos sobre la parcela $coord.');
      }
    }

    if (isFromMonument && _requiereColocacionEnBorde(template)) {
      final bool occupiesBorder = targetCoords.any(_isBorder);
      if (!occupiesBorder) {
        throw RuleError(
          '${template.name} debe ocupar al menos una parcela en el borde del tablero.',
        );
      }
    }

    // Validar ocupación de casillas y permitir sobreescrituras inteligentes
    final List<Propiedad> buildingsToRemove = <Propiedad>[];
    int ocupadaCount = 0;
    final Set<Propiedad> buildingsInTargetArea = <Propiedad>{};

    for (final String coord in targetCoords) {
      if (edificios.containsKey(coord)) {
        final Propiedad existing = edificios[coord]!;
        if (targetCoords.length <= existing.occupiedCoords.length) {
          throw RuleError(
            'El nuevo edificio debe ocupar mas parcelas que el existente en $coord.',
          );
        }
        ocupadaCount++;
        if (!buildingsInTargetArea.contains(existing)) {
          buildingsInTargetArea.add(existing);
          buildingsToRemove.add(existing);
        }
      }
    }

    // Si hay casillas ocupadas, validar que es una sobreescritura válida.
    if (ocupadaCount > 0) {
      // No puede colocar el mismo edificio dos veces
      for (final Propiedad existing in buildingsInTargetArea) {
        if (existing.template.id == template.id) {
          throw RuleError(
            'Ya existe un ${template.name} en esta zona. No puedes colocar el mismo edificio dos veces.',
          );
        }
      }
    }

    return _ValidacionConstruccion(
      player: p,
      targetCoords: targetCoords,
      buildingsToRemove: buildingsToRemove,
    );
  }

  /// Calcula coordenadas ocupadas por una plantilla desde origen y rotacion.
  List<String> _construirCoordenadasObjetivo(
    String normalizedOrigin,
    Edificio template,
    int rotationIdx,
  ) {
    final bool usesVisualOnlyRotation = _usaRotacionSoloVisual(template);
    final int logicalRotationIdx = usesVisualOnlyRotation ? 0 : rotationIdx;

    if (rotationIdx < 0 ||
        (usesVisualOnlyRotation
            ? rotationIdx >= 4
            : rotationIdx >= template.rotations.length)) {
      throw RuleError(
        'La orientacion seleccionada no es valida para ${template.name}.',
      );
    }

    final List<String> targetCoords = <String>[];
    final int startCol = normalizedOrigin.codeUnitAt(0) - 65;
    final int startRow = int.parse(normalizedOrigin.substring(1));
    final List<List<int>> selectedRotation =
        template.rotations[logicalRotationIdx];

    for (final List<int> offset in selectedRotation) {
      final int colIndex = startCol + offset[0];
      final int rowIndex = startRow + offset[1];
      if (colIndex < 0 ||
          colIndex >= tamanoTablero ||
          rowIndex > tamanoTablero ||
          rowIndex < 1) {
        throw const RuleError(
          'La rotacion elegida se sale de los limites del tablero.',
        );
      }

      final String colLetter = String.fromCharCode(65 + colIndex);
      targetCoords.add('$colLetter$rowIndex');
    }

    return targetCoords;
  }

  /// Indica si una plantilla solo rota visualmente sin cambiar huella logica.
  bool _usaRotacionSoloVisual(Edificio template) {
    return template.rotations.length == 1 &&
        template.rotations.first.length == 1;
  }

  /// Indica si un monumento debe tocar el borde del tablero.
  bool _requiereColocacionEnBorde(Edificio template) {
    switch (template.id) {
      case 'Faro':
      case 'TemploNeptuno':
      case 'ArcoTriunfo':
      case 'TorreObservacion':
      case 'PuertoImperial':
        return true;
      default:
        return false;
    }
  }

  /// Imprime el tablero actual en la version CLI.
  void imprimirTablero() {
    print('\n=== ESTADO DEL TABLERO (${tamanoTablero}x$tamanoTablero) ===');

    // Cabecera de columnas
    String header = '      ';
    for (int i = 0; i < tamanoTablero; i++) {
      header += '${String.fromCharCode(65 + i)}    ';
    }
    print(header);

    for (int r = 1; r <= tamanoTablero; r++) {
      String rowStr = '${r.toString().padLeft(2)} |';
      for (int c = 0; c < tamanoTablero; c++) {
        String coord = '${String.fromCharCode(65 + c)}$r';

        if (edificios.containsKey(coord)) {
          var b = edificios[coord]!;
          // Elegimos color según el ID del dueño
          String colorJugador = _obtenerColor(b.ownerId);
          // Mostramos el tipo del edificio (ej: R, C)
          // Imprimimos: [Color][Tipo][Reset]
          rowStr +=
              ' $colorJugador${nombreTipoEdificio(b.type)}${b.ownerId + 1}${ColorJugador.reset} |';
        } else if (propietariosLotes.containsKey(coord)) {
          int ownerId = propietariosLotes[coord]!;
          String color = _obtenerColor(ownerId); // Usamos tu función de ayuda
          rowStr +=
              ' ${color}L${ownerId + 1}${ColorJugador.reset} |'; // Ej: L1 (lote del jugador 1)
        } else {
          rowStr += ' .. |'; // Espacio vacío
        }
      }
      print(rowStr);
    }
    print('=======================================\n');
  }

  /// Devuelve la abreviatura visible de un tipo de edificio.
  String nombreTipoEdificio(TipoEdificio type) {
    switch (type) {
      case TipoEdificio.residential:
        return 'R';
      case TipoEdificio.commercial:
        return 'C';
      case TipoEdificio.civic:
        return 'V';
    }
  }

  /// Avanza el turno y dispara puntuacion de era si corresponde.
  void _endTurn() {
    indiceJugadorActual = (indiceJugadorActual + 1) % numeroJugadores;
    if (eraActual == Era.III && mercado.isEmpty && mazos[eraActual]!.isEmpty) {
      if (!rondaFinalEraIIIActiva) {
        rondaFinalEraIIIActiva = true;
        turnosRestantesRondaFinalEraIII = numeroJugadores;
        registrarResumenPendiente(
          'Se han agotado las parcelas de la Era III.',
          ["Comienza la ronda final: cada jugador tendrá un turno adicional."],
          isFinal: false,
        );
        print(
          '\n>> Se han agotado las parcelas de la Era III. Comienza la ronda final: cada jugador tendrá un turno adicional.',
        );
        return;
      }

      turnosRestantesRondaFinalEraIII--;
      if (turnosRestantesRondaFinalEraIII <= 0) {
        _scoreEra();
      }
      return;
    }

    if (mercado.isEmpty && mazos[eraActual]!.isEmpty) {
      _scoreEra();
    }
  }

  /// Calcula puntuaciones, monedas y resumen al final de una era.
  void _scoreEra() {
    final Era eraEvaluada = eraActual;
    final List<String> summaryLines = <String>[];

    print('\n=======================================');
    print('   PUNTUACIÓN DE LA ERA ${eraEvaluada.name}');
    print('=======================================');

    // Calcular invariantes para puntuación residencial
    int bonus = [4, 7, 10][eraEvaluada.index];
    List<Jugador> sortedPlayers = List.from(players)
      ..sort((a, b) => b.populationTrack.compareTo(a.populationTrack));
    int maxPop = sortedPlayers.first.populationTrack;
    List<Jugador> leaders = sortedPlayers
        .where((p) => p.populationTrack == maxPop)
        .toList();

    for (var p in players) {
      int points = 0;
      int populationPoints = 0;
      int civicPoints = 0;
      int monumentPoints = 0;
      int commercialEra3Points = 0;
      String populationBreakdown =
          'Track: ${p.populationTrack} | Bonus Era ${eraEvaluada.name}: +$bonus | Sin puntuación (track en 0)';

      // Residenciales: Puntuación según posición en el marcador de población
      if (p.populationTrack >= 1) {
        if (leaders.contains(p)) {
          populationPoints = p.populationTrack + bonus;
          populationBreakdown =
              'Track: ${p.populationTrack} | Bonus Era ${eraEvaluada.name}: +$bonus | Líder: ${p.populationTrack} + $bonus = +$populationPoints';
        } else {
          int aheadPop = 0;
          for (var sp in sortedPlayers) {
            if (sp.populationTrack > p.populationTrack) {
              aheadPop = sp.populationTrack;
              break;
            }
          }
          populationPoints = aheadPop;
          populationBreakdown =
              'Track: ${p.populationTrack} | Bonus Era ${eraEvaluada.name}: +$bonus (no aplica al no líder) | No líder: valor del siguiente por delante = +$populationPoints';
        }
      }
      points += populationPoints;

      int commBonus = 0;
      Set<Propiedad> countedCommercial = {};
      for (Propiedad b in edificios.values) {
        if (b.ownerId == p.id &&
            b.type == TipoEdificio.commercial &&
            !countedCommercial.contains(b)) {
          countedCommercial.add(b);
          switch (b.template.id) {
            case "PanaderiaI":
            case "PanaderiaII":
              commBonus += 1;
              break;
            case "AlfareriaI":
            case "AlfareriaII":
              commBonus += 1;
              break;
            case "ForoArtesanoL":
            case "ForoArtesano":
              commBonus += 2;
              break;
            case "FundicionRecta":
            case "FundicionCuadrada":
              commBonus += 3;
              break;
          }
        }
      }
      if (eraEvaluada != Era.III) {
        p.coins += commBonus;
        print('>> ${p.name} recauda $commBonus denarios de comerciales.');
      }

      if (eraEvaluada == Era.III) {
        Set<Propiedad> countedCommercialEra3 = {};
        for (Propiedad b in edificios.values) {
          if (b.ownerId == p.id &&
              b.type == TipoEdificio.commercial &&
              !countedCommercialEra3.contains(b)) {
            countedCommercialEra3.add(b);
            switch (b.template.id) {
              case "AlfareriaI":
              case "AlfareriaII":
                commercialEra3Points += 2;
                break;
              case "ForoArtesanoL":
              case "ForoArtesano":
                commercialEra3Points += 3;
                break;
              case "FundicionRecta":
              case "FundicionCuadrada":
                commercialEra3Points += 5;
                break;
              default:
                commercialEra3Points += 0;
            }
          }
        }
      }
      points += commercialEra3Points;

      Set<Propiedad> countedCivic = {};
      List<String> civicDetails = [];

      edificios.forEach((coord, b) {
        if (b.ownerId == p.id &&
            b.type == TipoEdificio.civic &&
            !countedCivic.contains(b)) {
          int civicFromBuilding = _calculateCivicBonus(b);
          civicPoints += civicFromBuilding;
          if (civicFromBuilding > 0) {
            civicDetails.add(
              '${b.template.name} (${b.occupiedCoords.first}): +$civicFromBuilding',
            );
          }
          countedCivic.add(b);
        }
      });
      points += civicPoints;

      String jupiterEraDetail = '';
      Set<Propiedad> countedJupiter = {};
      edificios.forEach((coord, b) {
        if (b.ownerId == p.id &&
            b.type == TipoEdificio.civic &&
            b.template.id == 'TemploJupiter' &&
            !countedJupiter.contains(b)) {
          countedJupiter.add(b);

          Set<String> jupiterNeighbors = {};
          for (String c in b.occupiedCoords) {
            for (String n in _getNeighbors(c)) {
              if (!b.occupiedCoords.contains(n)) {
                jupiterNeighbors.add(n);
              }
            }
          }

          Set<Propiedad> jupiterAdjacent = {};
          for (String n in jupiterNeighbors) {
            if (edificios.containsKey(n)) {
              jupiterAdjacent.add(edificios[n]!);
            }
          }

          int totalPlata = 0;
          for (Propiedad adj in jupiterAdjacent) {
            if (adj.type == TipoEdificio.commercial) {
              totalPlata += _commercialSilverValue(adj);
            }
          }
          int jupiterEraBonus = totalPlata * 2;
          monumentPoints += jupiterEraBonus;
          if (jupiterEraBonus > 0) {
            jupiterEraDetail =
                'Templo de Júpiter: +$jupiterEraBonus PV ($totalPlata platas × 2)';
          }
        }
      });
      points += monumentPoints;

      p.glory += points;
      print('${p.name}: +$points Gloria | Total: ${p.glory}');
      summaryLines.add('${p.name}: +$points Gloria | Total: ${p.glory}');
      print(
        '   Desglose -> Población: +$populationPoints | Cívicos: +$civicPoints | Monumentos: +$monumentPoints${eraEvaluada == Era.III ? ' | Comerciales (Era III): +$commercialEra3Points' : ''}',
      );
      summaryLines.add(
        '   Desglose -> Población: +$populationPoints | Cívicos: +$civicPoints | Monumentos: +$monumentPoints${eraEvaluada == Era.III ? ' | Comerciales (Era III): +$commercialEra3Points' : ''}',
      );
      print('   Población detalle -> $populationBreakdown');
      summaryLines.add('   Población detalle -> $populationBreakdown');
      if (p.populationTrack == 0) {
        print(
          '   Nota: track de población en 0, sin puntos residenciales esta era.',
        );
        summaryLines.add(
          '   Nota: track de población en 0, sin puntos residenciales esta era.',
        );
      }
      if (civicDetails.isNotEmpty) {
        print('   Cívicos que puntuaron: ${civicDetails.join(' | ')}');
        summaryLines.add(
          '   Cívicos que puntuaron: ${civicDetails.join(' | ')}',
        );
      }
      if (jupiterEraDetail.isNotEmpty) {
        print('   $jupiterEraDetail');
        summaryLines.add('   $jupiterEraDetail');
      }

      final String commercialDetail = eraEvaluada == Era.III
          ? ' | Comerciales: +$commercialEra3Points'
          : '';
      summaryLines.add(
        '${p.name}: +$points PV | Total: ${p.glory} | Población: +$populationPoints | Cívicos: +$civicPoints | Monumentos: +$monumentPoints$commercialDetail',
      );
    }

    if (eraEvaluada == Era.III) {
      _finalScoring(summaryLines);
    } else {
      final Era siguienteEra = Era.values[eraEvaluada.index + 1];
      summaryLines.add('');
      summaryLines.add(
        'Pulsa Confirmar para comenzar la ERA ${siguienteEra.name}.',
      );
      registrarResumenPendiente(
        'Resultados de la ERA ${eraEvaluada.name}',
        summaryLines,
        advanceToNextEra: true,
      );
    }
  }

  /// Valor de plata que aporta un edificio comercial.
  int _commercialSilverValue(Propiedad b) {
    switch (b.template.id) {
      case "PanaderiaI":
      case "PanaderiaII":
        return 1;
      case "AlfareriaI":
      case "AlfareriaII":
        return 1;
      case "ForoArtesanoL":
      case "ForoArtesano":
        return 2;
      case "FundicionRecta":
      case "FundicionCuadrada":
        return 3;
      default:
        return 0;
    }
  }

  /// Valor de poblacion que aporta un edificio residencial.
  int _residentialPopulationValue(Propiedad b) {
    switch (b.template.id) {
      case "DomusI":
      case "DomusII":
        return 1;
      case "DomusMaximaI":
      case "DomusMaximaII":
        return 2;
      case "InsulaL":
      case "Insula":
        return 4;
      case "GranInsulaCuadrada":
      case "GranInsulaRecta":
        return 6;
      default:
        return 0;
    }
  }

  /// Calcula los puntos de un edificio civico segun sus adyacencias.
  int _calculateCivicBonus(Propiedad b) {
    int bonus = 0;
    Set<String> neighborsToCheck = {};

    // Recopilamos todos los vecinos de todas las piezas del edificio
    for (String coord in b.occupiedCoords) {
      List<String> neighbors = _getNeighbors(coord);
      for (String n in neighbors) {
        // Solo añadimos si no es parte del propio edificio
        if (!b.occupiedCoords.contains(n)) {
          neighborsToCheck.add(n);
        }
      }
    }

    // Convertimos coordenadas vecinas en edificios adyacentes únicos
    Set<Propiedad> adjacentBuildings = {};
    for (String n in neighborsToCheck) {
      if (edificios.containsKey(n)) {
        adjacentBuildings.add(edificios[n]!);
      }
    }

    switch (b.template.id) {
      case "Fuente":
        // Da 1 PV por cada edificio adyacente (cualquier tipo)
        bonus += adjacentBuildings.length;
        break;
      case "Biblioteca":
        // Da 1 PV por cada 2 ciudadanos en residenciales adyacentes
        int totalCitizens = 0;
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.residential) {
            totalCitizens += _residentialPopulationValue(neighbor);
          }
        }
        bonus += totalCitizens ~/ 2; // División entera
        break;
      case "BibliotecaVIP":
        // Gana 1 PV por cada ciudadano en residenciales adyacentes
        int totalCitizensVIP = 0;
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.residential) {
            totalCitizensVIP += _residentialPopulationValue(neighbor);
          }
        }
        bonus += totalCitizensVIP;
        break;
      case "FuenteMajestuosa":
        // Da 1 PV por cada edificio adyacente
        bonus += adjacentBuildings.length;
        break;
      case "JardinLujoso":
        // Gana 3 PV por cada edificio municipal adyacente
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.civic) {
            bonus += 3;
          }
        }
        break;
      case "Mercado":
        // Gana 2 PV por cada plata en comerciales adyacentes
        int totalPlata = 0;
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.commercial) {
            totalPlata += _commercialSilverValue(neighbor);
          }
        }
        bonus += totalPlata * 2;
        break;
      case "Mercadillo":
        // Gana 1 PV por cada plata en comerciales adyacentes
        int totalPlataMercadillo = 0;
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.commercial) {
            totalPlataMercadillo += _commercialSilverValue(neighbor);
          }
        }
        bonus += totalPlataMercadillo;
        break;
      case "Jardin":
        // Gana 2 PV por cada edificio municipal adyacente
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.civic) {
            bonus += 2;
          }
        }
        break;
      case "Panteon":
        // Gana 3 PV por cada edificio municipal adyacente
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.civic) {
            bonus += 3;
          }
        }
        break;
      case "ForoRomano":
        // Gana 2 PV por cada plata en comerciales adyacentes
        int totalPlataForo = 0;
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.commercial) {
            totalPlataForo += _commercialSilverValue(neighbor);
          }
        }
        bonus += totalPlataForo * 2;
        break;
      case "CircoMaximo":
        // Gana 1 PV por cada ciudadano en residenciales adyacentes
        int totalCitizensCirco = 0;
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.residential) {
            totalCitizensCirco += _residentialPopulationValue(neighbor);
          }
        }
        bonus += totalCitizensCirco;
        break;
      case "Faro":
        // Gana 2 PV por cada plata en edificios adyacentes
        int totalPlataFaro = 0;
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.commercial) {
            totalPlataFaro += _commercialSilverValue(neighbor);
          }
        }
        bonus += totalPlataFaro * 2;
        break;
      case "TorreObservacion":
        // Gana 1 PV por cada persona en edificios adyacentes
        int totalPeopleTorre = 0;
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.residential) {
            totalPeopleTorre += _residentialPopulationValue(neighbor);
          }
        }
        bonus += totalPeopleTorre;
        break;
      case "TemploJupiter":
        // Gana 2 PV por cada plata en comerciales adyacentes
        int totalPlataJupiter = 0;
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.commercial) {
            totalPlataJupiter += _commercialSilverValue(neighbor);
          }
        }
        bonus += totalPlataJupiter * 2;
        break;
      case "Coliseo":
        // Gana 1 PV por cada persona en edificio adyacente
        int totalPeopleColiseo = 0;
        for (Propiedad neighbor in adjacentBuildings) {
          if (neighbor.type == TipoEdificio.residential) {
            totalPeopleColiseo += _residentialPopulationValue(neighbor);
          }
        }
        bonus += totalPeopleColiseo;
        break;
      case "EstatuaRomulo":
        // Gana 2 PV por cada edificio adyacente
        bonus += adjacentBuildings.length * 2;
        break;
      default:
        bonus = 0;
    }
    return bonus;
  }

  /// Calcula monedas extra generadas por monumentos propios.
  int _calculateMonumentCoinBonus(Jugador p) {
    int bonus = 0;
    // Bonuses from own monuments
    Set<Propiedad> countedOwnCivics = {};
    for (Propiedad b in edificios.values) {
      if (b.ownerId == p.id &&
          b.type == TipoEdificio.civic &&
          !countedOwnCivics.contains(b)) {
        countedOwnCivics.add(b);
        switch (b.template.id) {
          case "BodegaReal":
            bonus += 4;
            break;
          case "PuertoImperial":
            bonus += 3;
            break;
          case "TemploApolo":
            bonus += 2;
            break;
          case "TemploNeptuno":
            bonus += 1;
            break;
          case "TemploVulcano":
            // +1 por cada edificio adyacente
            Set<String> neighborsToCheck = {};
            for (String c in b.occupiedCoords) {
              List<String> neighbors = _getNeighbors(c);
              for (String n in neighbors) {
                if (!b.occupiedCoords.contains(n)) {
                  neighborsToCheck.add(n);
                }
              }
            }
            Set<Propiedad> adjacentBuildings = {};
            for (String n in neighborsToCheck) {
              if (edificios.containsKey(n)) {
                adjacentBuildings.add(edificios[n]!);
              }
            }
            bonus += adjacentBuildings.length;
            break;
          default:
            break;
        }
      }
    }
    return bonus;
  }

  /// Texto corto de requisitos para mostrar en UI y CLI.
  String monumentRequirementSummary(String monumentId) {
    return _monumentRequirementSummary(monumentId);
  }

  /// Devuelve el texto interno de requisitos de un monumento.
  String _monumentRequirementSummary(String monumentId) {
    switch (monumentId) {
      case "Panteon":
        return 'Req: 8/8 marcadores disponibles';
      case "ForoRomano":
        return 'Req: población >= 6';
      case "CircoMaximo":
        return 'Req: al menos 14 solares comprados';
      case "TemploVulcano":
        return 'Req: >= 4 casillas comerciales';
      case "TemploMinerva":
        return 'Req: >= 4 casillas residenciales';
      case "TorreMaravillas":
        return 'Req: edificio previo de >= 3 casillas';
      case "TemploMarte":
        return 'Req: edificio >= 3 casillas y comercial >= 3';
      case "TemploNeptuno":
        return 'Req: >= 2 edificios cívicos + ocupar al menos una parcela en borde';
      case "Faro":
        return 'Req: edificio previo de >= 4 casillas + colocar en borde';
      case "TorreObservacion":
        return 'Req: >= 2 parcelas en borde';
      case "EstatuaRomulo":
        return 'Req: >= 6 edificios';
      case "TemploVenus":
        return 'Req: comercial >= 4 platas';
      case "TemploApolo":
        return 'Req: >= 3 edificios residenciales';
      case "ArcoTriunfo":
        return 'Req: colocar en borde';
      case "PuertoImperial":
        return 'Req: colocar en borde';
      case "TemploJupiter":
      case "Coliseo":
      case "BodegaReal":
      case "Regia":
        return 'Req: sin requisito previo';
      default:
        return 'Req: consultar reglas';
    }
  }

  /// Valida requisitos previos para construir un monumento.
  void _validateMonumentRequirements(Jugador p, Edificio template) {
    switch (template.id) {
      case "Panteon":
        if (p.availableMarkers != 8) {
          throw const RuleError(
            'Debes tener todos tus marcadores en la bandeja (0 en el tablero).',
          );
        }
        break;
      case "ForoRomano":
        if (p.populationTrack < 6) {
          throw const RuleError(
            'Debes tener al menos 6 en el track de poblacion.',
          );
        }
        break;
      case "CircoMaximo":
        final int solaresComprados = p.lots.length;
        if (solaresComprados < 14) {
          throw const RuleError('Debes haber comprado al menos 14 solares.');
        }
        break;
      case "TemploVulcano":
        final int commercialBuildings = edificios.values
            .where(
              (b) => b.ownerId == p.id && b.type == TipoEdificio.commercial,
            )
            .length;
        if (commercialBuildings < 4) {
          throw const RuleError(
            'Debes tener al menos 4 parcelas ocupadas por edificios comerciales.',
          );
        }
        break;
      case "TemploMinerva":
        final int residentialBuildings = edificios.values
            .where(
              (b) => b.ownerId == p.id && b.type == TipoEdificio.residential,
            )
            .length;
        if (residentialBuildings < 4) {
          throw const RuleError(
            'Debes tener al menos 4 parcelas ocupadas por edificios residenciales.',
          );
        }
        break;
      case "TorreMaravillas":
        final bool hasLargeBuilding = edificios.values.any(
          (b) => b.ownerId == p.id && b.occupiedCoords.length >= 3,
        );
        if (!hasLargeBuilding) {
          throw const RuleError(
            'Debes haber edificado un edificio de al menos 3 parcelas.',
          );
        }
        break;
      case "TemploMarte":
        final bool hasLargeBuildingMarte = edificios.values.any(
          (b) => b.ownerId == p.id && b.occupiedCoords.length >= 3,
        );
        int commercialValue = 0;
        for (final Propiedad building in edificios.values) {
          if (building.ownerId == p.id &&
              building.type == TipoEdificio.commercial) {
            commercialValue += _commercialSilverValue(building);
          }
        }
        if (!hasLargeBuildingMarte || commercialValue < 3) {
          throw const RuleError(
            'Debes poseer un edificio de al menos 3 parcelas y comerciales que valgan al menos 3 monedas.',
          );
        }
        break;
      case "TemploNeptuno":
        final int civicCount = edificios.values
            .where((b) => b.ownerId == p.id && b.type == TipoEdificio.civic)
            .length;
        if (civicCount < 2) {
          throw const RuleError('Debes tener al menos 2 edificios civicos.');
        }
        // Verificación de borde se realiza después, en actionBuild,
        // ya que depende de la huella final según la rotación elegida.
        break;
      case "Faro":
        final bool hasVeryLargeBuilding = edificios.values.any(
          (b) => b.ownerId == p.id && b.occupiedCoords.length >= 4,
        );
        if (!hasVeryLargeBuilding) {
          throw const RuleError(
            'Debes haber edificado un edificio de al menos 4 parcelas.',
          );
        }
        // En borde: verificar después.
        break;
      case "TorreObservacion":
        // 2 parcelas en borde: simplificar, contar lotes en borde.
        final int borderLots = p.lots.where((lot) => _isBorder(lot)).length;
        if (borderLots < 2) {
          throw const RuleError(
            'Debes tener al menos 2 parcelas en el borde del tablero.',
          );
        }
        break;
      case "EstatuaRomulo":
        final int totalBuildings = edificios.values
            .where((b) => b.ownerId == p.id)
            .length;
        if (totalBuildings < 6) {
          throw const RuleError('Debes poseer al menos 6 edificios.');
        }
        break;
      case "TemploVenus":
        int commercialValueVenus = 0;
        for (final Propiedad building in edificios.values) {
          if (building.ownerId == p.id &&
              building.type == TipoEdificio.commercial) {
            commercialValueVenus += _commercialSilverValue(building);
          }
        }
        if (commercialValueVenus < 4) {
          throw const RuleError(
            'Debes tener edificios comerciales por un valor de 4 o más platas.',
          );
        }
        break;
      case "TemploApolo":
        final int residentialCount = edificios.values
            .where(
              (b) => b.ownerId == p.id && b.type == TipoEdificio.residential,
            )
            .length;
        if (residentialCount < 3) {
          throw const RuleError(
            'Debes tener al menos 3 edificios residenciales.',
          );
        }
        break;
      // Arco del Triunfo y Puerto Imperial requieren borde, verificar después.
      default:
        break;
    }
  }

  /// Indica si una coordenada esta en el borde del tablero.
  bool _isBorder(String coord) {
    String col = coord[0];
    int row = int.parse(coord.substring(1));
    return col == 'A' ||
        col == String.fromCharCode(65 + tamanoTablero - 1) ||
        row == 1 ||
        row == tamanoTablero;
  }

  /// Indica si una coordenada pertenece al tablero actual.
  bool isCoordOnBoard(String coord) {
    String normalized = coord.toUpperCase().trim();
    if (!RegExp(r'^[A-Z][0-9]+$').hasMatch(normalized)) {
      return false;
    }

    int col = normalized.codeUnitAt(0) - 65;
    int? row = int.tryParse(normalized.substring(1));
    if (row == null) {
      return false;
    }

    return col >= 0 && col < tamanoTablero && row >= 1 && row <= tamanoTablero;
  }

  /// Devuelve las coordenadas que ocuparia una construccion.
  List<String> targetCoordsForPlacement(
    String originCoord,
    Edificio template,
    int rotationIdx,
  ) {
    return List<String>.unmodifiable(
      _construirCoordenadasObjetivo(
        originCoord.toUpperCase().trim(),
        template,
        rotationIdx,
      ),
    );
  }

  /// Aplica beneficios inmediatos de monumentos al construirlos.
  void _applyMonumentBenefits(
    Jugador p,
    Edificio template,
    List<String> occupiedCoords,
  ) {
    // Beneficios para el constructor (solo población inmediata)
    switch (template.id) {
      case "Regia":
        p.populationTrack += 9;
        print('>> ${p.name} gana 9 de población de la Regia.');
        break;
      case "TemploVenus":
        p.populationTrack += 4;
        print('>> ${p.name} gana 4 de población del Templo de Venus.');
        break;
      case "ArcoTriunfo":
        p.populationTrack += 7;
        print('>> ${p.name} gana 7 de población del Arco del Triunfo.');
        break;
      case "TemploMarte":
        p.populationTrack += 5;
        print('>> ${p.name} gana 5 de población del Templo de Marte.');
        break;
      case "Coliseo":
        // Efecto inmediato: +3 monedas a cada jugador con al menos un edificio adyacente
        Set<String> coliseumNeighbors = {};
        for (String coord in occupiedCoords) {
          for (String n in _getNeighbors(coord)) {
            if (!occupiedCoords.contains(n)) coliseumNeighbors.add(n);
          }
        }

        Set<Propiedad> coliseumAdjacent = {};
        for (String n in coliseumNeighbors) {
          if (edificios.containsKey(n)) coliseumAdjacent.add(edificios[n]!);
        }

        Set<int> coliseumAdjacentOwners = {};
        for (Propiedad adj in coliseumAdjacent) {
          coliseumAdjacentOwners.add(adj.ownerId);
        }

        print('\n>> ${p.name} coloca el Coliseo.');
        print(
          '   MONEDAS OTORGADAS INMEDIATAMENTE (+3 por tener edificio adyacente):',
        );
        for (Jugador player in players) {
          if (coliseumAdjacentOwners.contains(player.id)) {
            player.coins += 3;
            print('   ${player.name}: +3 monedas (Total: ${player.coins})');
          } else {
            print('   ${player.name}: +0 monedas (sin edificios adyacentes)');
          }
        }
        break;
      case "TemploJupiter":
        // Puntuacion inmediata por construccion del Templo de Jupiter
        Set<String> neighborsToCheck = {};
        for (String coord in occupiedCoords) {
          List<String> neighbors = _getNeighbors(coord);
          for (String n in neighbors) {
            if (!occupiedCoords.contains(n)) {
              neighborsToCheck.add(n);
            }
          }
        }

        Set<Propiedad> adjacentBuildings = {};
        for (String n in neighborsToCheck) {
          if (edificios.containsKey(n)) {
            adjacentBuildings.add(edificios[n]!);
          }
        }

        // 1. Recopilar dueños únicos de comerciales adyacentes
        Set<int> ownerIds = {};
        List<String> buildingDetails = [];

        for (Propiedad neighbor in adjacentBuildings) {
          buildingDetails.add(neighbor.template.name);
          ownerIds.add(neighbor.ownerId);
        }

        // 2. Efecto inmediato: +2 PV a cada jugador con al menos un edificio adyacente
        Map<int, int> immediatePointsByPlayer = {};
        for (int ownerId in ownerIds) {
          immediatePointsByPlayer[ownerId] = 2;
        }

        immediatePointsByPlayer.forEach((playerId, gainedPoints) {
          players[playerId].glory += gainedPoints;
        });

        print('\n>> ${p.name} coloca el Templo de Júpiter.');

        if (buildingDetails.isNotEmpty) {
          print('   Edificios adyacentes: ${buildingDetails.join(", ")}');
        } else {
          print('   Sin edificios adyacentes.');
        }

        print(
          '   PUNTOS OTORGADOS INMEDIATAMENTE (+2 por tener edificio adyacente):',
        );
        for (Jugador player in players) {
          int gainedPoints = immediatePointsByPlayer[player.id] ?? 0;
          print(
            '   ${player.name}: +$gainedPoints PV (Total Gloria: ${player.glory})',
          );
        }
        break;
      default:
        break;
    }

    // El resto de beneficios de monedas/PV se mantienen en income y scoring,
    // excepto los efectos instantaneos como Templo de Jupiter.
  }

  /// Devuelve las coordenadas ortogonales vecinas de una casilla.
  List<String> _getNeighbors(String coord) {
    String colStr = coord.substring(0, 1);
    int row = int.parse(coord.substring(1));
    int col = colStr.codeUnitAt(0);

    return [
      '${String.fromCharCode(col)}${row - 1}',
      '${String.fromCharCode(col)}${row + 1}',
      '${String.fromCharCode(col - 1)}$row',
      '${String.fromCharCode(col + 1)}$row',
    ];
  }

  /// Calcula la puntuacion final y registra el resumen de partida.
  void _finalScoring([List<String> eraSummaryLines = const []]) {
    partidaFinalizada = true;
    final List<String> summaryLines = <String>[];

    if (eraSummaryLines.isNotEmpty) {
      summaryLines.add('Resultados de la era III:');
      summaryLines.addAll(eraSummaryLines);
      summaryLines.add('');
    }

    print('\n--- PUNTUACIÓN FINAL ---');
    summaryLines.add('Bonificación final por parcelas vacías:');

    for (var p in players) {
      int emptyLotsCount = 0;

      for (String coord in p.lots) {
        if (!edificios.containsKey(coord)) {
          emptyLotsCount++;
        }
      }

      p.glory += emptyLotsCount;
      print('${p.name} recibe $emptyLotsCount puntos por parcelas vacías.');
      print('RESULTADO FINAL: ${p.name} - ${p.glory} Puntos de Gloria.');
      summaryLines.add(
        '${p.name}: +$emptyLotsCount PV por parcelas vacías | Total final: ${p.glory}',
      );
    }

    List<Jugador> ranking = List<Jugador>.from(players)
      ..sort((a, b) {
        int gloryComparison = b.glory.compareTo(a.glory);
        if (gloryComparison != 0) {
          return gloryComparison;
        }
        return a.id.compareTo(b.id);
      });

    print('\n=== RANKING FINAL ===');
    summaryLines.add('');
    summaryLines.add('Ranking final:');
    for (int i = 0; i < ranking.length; i++) {
      Jugador player = ranking[i];
      print('${i + 1}. ${player.name} - ${player.glory} Puntos de Gloria');
      summaryLines.add('${i + 1}. ${player.name} — ${player.glory} PV');
    }

    int topScore = ranking.first.glory;
    List<Jugador> winners = ranking.where((p) => p.glory == topScore).toList();
    if (winners.length == 1) {
      print(
        'GANADOR: ${winners.first.name} con ${winners.first.glory} Puntos de Gloria.',
      );
      summaryLines.add('');
      summaryLines.add(
        'Ganador: ${winners.first.name} con ${winners.first.glory} PV.',
      );
    } else {
      print(
        'EMPATE EN EL PRIMER PUESTO: ${winners.map((p) => p.name).join(', ')} con $topScore Puntos de Gloria.',
      );
      summaryLines.add('');
      summaryLines.add(
        'Empate en cabeza: ${winners.map((p) => p.name).join(', ')} con $topScore PV.',
      );
    }

    registrarResumenPendiente(
      'Resultados finales de la partida',
      summaryLines,
      isFinal: true,
    );
  }

  /// Serializa la partida completa como cadena JSON.
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Reconstruye una partida desde una cadena JSON.
  static Juego fromJsonString(String jsonString) {
    final Map<String, dynamic> json =
        jsonDecode(jsonString) as Map<String, dynamic>;
    return Juego.fromJson(json);
  }

  /// Serializa la partida completa a un mapa JSON.
  Map<String, dynamic> toJson({bool includePendingSummary = true}) {
    final Map<String, dynamic> json = <String, dynamic>{
      'numeroJugadores': numeroJugadores,
      'tamanoTablero': tamanoTablero,
      'players': players.map((p) => p.toJson()).toList(),
      'indiceJugadorActual': indiceJugadorActual,
      'eraActual': eraActual.name,
      'rondaFinalEraIIIActiva': rondaFinalEraIIIActiva,
      'turnosRestantesRondaFinalEraIII': turnosRestantesRondaFinalEraIII,
      'partidaFinalizada': partidaFinalizada,
      'propietariosLotes': propietariosLotes,
      'edificios': edificios.map((k, v) => MapEntry(k, v.toJson())),
      'mazos': mazos.map(
        (k, v) => MapEntry(k.name, v.map((d) => d.toJson()).toList()),
      ),
      'mercado': mercado.map((d) => d.toJson()).toList(),
      'monumentosDisponibles': monumentosDisponibles.map((m) => m.id).toList(),
    };

    if (includePendingSummary) {
      json.addAll(<String, dynamic>{
        'tituloResumenPendiente': tituloResumenPendiente,
        'lineasResumenPendiente': List<String>.from(lineasResumenPendiente),
        'resumenPendienteEsFinal': resumenPendienteEsFinal,
        'avanzarAEraSiguienteDespuesDeResumen':
            avanzarAEraSiguienteDespuesDeResumen,
      });
    }

    return json;
  }

  /// Reconstruye una partida desde un mapa JSON.
  factory Juego.fromJson(Map<String, dynamic> json) {
    int numeroJugadores = json['numeroJugadores'];
    Juego game = Juego._fromJson(numeroJugadores);
    game.tamanoTablero = json['tamanoTablero'];
    game.players.clear();
    game.players.addAll(
      (json['players'] as List).map((p) => Jugador.fromJson(p)),
    );
    game.indiceJugadorActual = json['indiceJugadorActual'];
    game.eraActual = Era.values.firstWhere((e) => e.name == json['eraActual']);
    game.rondaFinalEraIIIActiva = json['rondaFinalEraIIIActiva'] == true;
    game.turnosRestantesRondaFinalEraIII =
        json['turnosRestantesRondaFinalEraIII'] ?? 0;
    game.partidaFinalizada = json['partidaFinalizada'] == true;
    game.tituloResumenPendiente = json['tituloResumenPendiente'] as String?;
    game.lineasResumenPendiente =
        ((json['lineasResumenPendiente'] as List?) ?? const <dynamic>[])
            .map((line) => line.toString())
            .toList();
    game.resumenPendienteEsFinal = json['resumenPendienteEsFinal'] == true;
    game.avanzarAEraSiguienteDespuesDeResumen =
        json['avanzarAEraSiguienteDespuesDeResumen'] == true;
    game.propietariosLotes.clear();
    game.propietariosLotes.addAll(
      (json['propietariosLotes'] as Map).cast<String, int>(),
    );
    game.edificios.clear();
    final Map<String, Propiedad> canonicalBuildings = {};
    game.edificios.addAll(
      (json['edificios'] as Map).cast<String, dynamic>().map((k, v) {
        final Map<String, dynamic> buildingJson = (v as Map)
            .cast<String, dynamic>();
        final List<String> coords =
            (buildingJson['coordenadasOcupadas'] as List)
                .cast<String>()
                .toList()
              ..sort();
        final String signature =
            '${buildingJson['idPropietario']}|${buildingJson['idPlantilla']}|${coords.join(',')}';

        final Propiedad sharedBuilding = canonicalBuildings.putIfAbsent(
          signature,
          () => Propiedad.fromJson(buildingJson),
        );

        return MapEntry(k, sharedBuilding);
      }),
    );
    game.mazos.clear();
    game.mazos.addAll(
      (json['mazos'] as Map).cast<String, dynamic>().map(
        (k, v) => MapEntry(
          Era.values.firstWhere((e) => e.name == k),
          (v as List).map((d) => CartaEscritura.fromJson(d)).toList(),
        ),
      ),
    );
    game.mercado.clear();
    game.mercado.addAll(
      (json['mercado'] as List).map((d) => CartaEscritura.fromJson(d)),
    );
    game.monumentosDisponibles.clear();
    List<String> monumentRefs = (json['monumentosDisponibles'] as List)
        .cast<String>();
    for (String ref in monumentRefs) {
      final Edificio? template = buscarEdificioPorId(ref);
      if (template == null) {
        continue;
      }
      game.monumentosDisponibles.add(template);
    }
    game._actualizarMarcadoresPoblacion(); // Recalcular población después de cargar
    return game;
  }

  /// Constructor interno usado por la reconstruccion desde JSON.
  Juego._fromJson(this.numeroJugadores) : _playerKinds = null {
    // No inicializar nada, solo para factory
  }

  /// Validacion previa para catalogo.
  ///
  /// Usa el mismo motor de validacion que la colocacion real, pero probando
  /// todas las rotaciones hasta encontrar una valida.
  String? puedeColocarEdificio(
    String originCoord,
    Edificio template, {
    required bool isFromMonument,
  }) {
    if (partidaFinalizada) {
      return 'La partida ha terminado. No se pueden colocar más edificios.';
    }
    final Jugador p = players[indiceJugadorActual];
    final List<Edificio> sourceBuildings = isFromMonument
        ? monumentosDisponibles
        : p.availableBuildings;
    final int buildingIdx = sourceBuildings.indexWhere(
      (building) => building.id == template.id,
    );

    if (buildingIdx < 0) {
      return isFromMonument
          ? 'El monumento seleccionado ya no esta disponible.'
          : 'El edificio seleccionado ya no esta disponible.';
    }

    final int totalRotaciones = _usaRotacionSoloVisual(template)
        ? 4
        : template.rotations.length;
    String? lastError;

    for (int rotIdx = 0; rotIdx < totalRotaciones; rotIdx++) {
      try {
        _resolveBuildValidation(
          originCoord,
          template,
          rotIdx,
          buildingIdx,
          isFromMonument,
        );
        return null;
      } on RuleError catch (error) {
        lastError = error.message;
      }
    }

    return lastError ??
        'No hay rotación válida para este edificio en esa zona.';
  }
}
