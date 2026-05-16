// ignore_for_file: avoid_print

import 'dart:io';
import 'domain/foundations_of_rome/foundations_of_rome.dart';

String _getBuildingSizeCli(Edificio template) {
  final List<List<int>> firstRotation = template.rotations[0];
  if (firstRotation.isEmpty) return '0x0';

  int minX = firstRotation[0][0];
  int maxX = firstRotation[0][0];
  int minY = firstRotation[0][1];
  int maxY = firstRotation[0][1];

  for (final List<int> coord in firstRotation) {
    minX = minX > coord[0] ? coord[0] : minX;
    maxX = maxX < coord[0] ? coord[0] : maxX;
    minY = minY > coord[1] ? coord[1] : minY;
    maxY = maxY < coord[1] ? coord[1] : maxY;
  }

  final int width = maxX - minX + 1;
  final int height = maxY - minY + 1;
  return '${width}x$height';
}

String _monumentRequirementSummaryCli(String monumentId) {
  switch (monumentId) {
    case 'Panteon':
      return 'Req: 8/8 marcadores disponibles';
    case 'ForoRomano':
      return 'Req: poblacion >= 6';
    case 'CircoMaximo':
      return 'Req: al menos 14 solares comprados';
    case 'TemploVulcano':
      return 'Req: >= 4 casillas comerciales';
    case 'TemploMinerva':
      return 'Req: >= 4 casillas residenciales';
    case 'TorreMaravillas':
      return 'Req: edificio previo de >= 3 casillas';
    case 'TemploMarte':
      return 'Req: edificio >= 3 casillas y comercial >= 3';
    case 'TemploNeptuno':
      return 'Req: >= 2 edificios civicos + ocupar al menos una parcela en borde';
    case 'Faro':
      return 'Req: edificio previo de >= 4 casillas + colocar en borde';
    case 'TorreObservacion':
      return 'Req: >= 2 parcelas en borde';
    case 'EstatuaRomulo':
      return 'Req: >= 6 edificios';
    case 'TemploVenus':
      return 'Req: comercial >= 4 platas';
    case 'TemploApolo':
      return 'Req: >= 3 edificios residenciales';
    case 'ArcoTriunfo':
      return 'Req: colocar en borde';
    case 'PuertoImperial':
      return 'Req: colocar en borde';
    case 'TemploJupiter':
    case 'Coliseo':
    case 'BodegaReal':
    case 'Regia':
      return 'Req: sin requisito previo';
    default:
      return 'Req: consultar reglas';
  }
}

void _intentarConstruir(
  Juego game,
  String origin,
  Edificio building,
  int rotationIdx,
  int buildingIdx,
  bool isFromMonument,
) {
  try {
    game.construir(
      origin,
      building,
      rotationIdx,
      buildingIdx,
      isFromMonument,
    );
  } on RuleError catch (error) {
    print('\n!! ${error.message}');
  }
}

void _intentarAccionJuego(void Function() action) {
  try {
    action();
  } on RuleError catch (error) {
    print('\n!! ${error.message}');
  }
}

void runForCli() {
  print('--- BIENVENIDO A FOUNDATIONS OF ROME (CLI VERSION) ---');

  final File saveFile = File('partida_guardada.json');
  late Juego game;
  if (saveFile.existsSync()) {
    stdout.write('Se encontro una partida guardada. Quieres cargarla? [s]/n: ');
    final String? loadChoice = stdin.readLineSync()?.toLowerCase().trim();
    if (loadChoice == '' ||
        loadChoice == 's' ||
        loadChoice == 'si' ||
        loadChoice == 'y' ||
        loadChoice == 'yes') {
      try {
        final String jsonString = saveFile.readAsStringSync();
        game = Juego.fromJsonString(jsonString);
        print('Partida cargada exitosamente.');
      } catch (e) {
        print('Error al cargar la partida. Iniciando nueva partida.');
        stdout.write('Numero de jugadores (2-5): ');
        final int num = int.tryParse(stdin.readLineSync() ?? '2') ?? 2;
        game = Juego(num.clamp(2, 5));
      }
    } else {
      stdout.write('Numero de jugadores (2-5): ');
      final int num = int.tryParse(stdin.readLineSync() ?? '2') ?? 2;
      game = Juego(num.clamp(2, 5));
    }
  } else {
    stdout.write('Numero de jugadores (2-5): ');
    final int num = int.tryParse(stdin.readLineSync() ?? '2') ?? 2;
    game = Juego(num.clamp(2, 5));
  }

  while (true) {
    game.imprimirEstado();
    game.imprimirTablero();

    print(
      '\nAcciones: 1. Ingresos | 2. Comprar Lote | 3. Construir/Mejorar | 4. Guardar Partida | 5. Cargar Partida | 0. Salir',
    );
    stdout.write('Elige: ');
    final String? choice = stdin.readLineSync();

    if (choice == '1') {
      _intentarAccionJuego(game.accionIngresos);
    } else if (choice == '2') {
      if (game.mercado.isEmpty) {
        print(
          '\n!! No quedan parcelas disponibles para comprar en el mercado.',
        );
        continue;
      }
      stdout.write('Indice del lote (0-5): ');
      final int idx = int.tryParse(stdin.readLineSync() ?? '0') ?? 0;
      _intentarAccionJuego(() => game.comprarParcela(idx));
    } else if (choice == '3') {
      stdout.write('Coordenada de origen (ej: A3): ');
      final String origin = (stdin.readLineSync() ?? '').toUpperCase().trim();

      final Jugador currentPlayer = game.players[game.indiceJugadorActual];
      if (!game.isCoordOnBoard(origin)) {
        print('\n!! Coordenada invalida o fuera del tablero.');
        continue;
      }
      if (!currentPlayer.lots.contains(origin)) {
        print('\n!! Debes elegir una parcela que te pertenezca.');
        continue;
      }

      print('\n--- BANDEJA DE EDIFICIOS ---');
      if (currentPlayer.availableBuildings.isEmpty) {
        print('  No tienes edificios disponibles para construir.');
        continue;
      }
      for (int i = 0; i < currentPlayer.availableBuildings.length; i++) {
        final Edificio template = currentPlayer.availableBuildings[i];
        final String size = _getBuildingSizeCli(template);
        final String typeTag = game.nombreTipoEdificio(template.type);
        print('  [$i] [$typeTag] ${template.name} - $size');
      }
      print('  [-1] Cancelar');
      print('  [P] Elegir de bandeja comun (monumentos)');
      stdout.write('Elige edificio o [P] para monumentos: ');
      final String? choiceEdificio = stdin.readLineSync()?.toLowerCase().trim();

      if (choiceEdificio == 'p') {
        print('\n--- BANDEJA DE MONUMENTOS ---');
        if (game.monumentosDisponibles.isEmpty) {
          print('  No hay monumentos disponibles.');
          continue;
        }
        for (int i = 0; i < game.monumentosDisponibles.length; i++) {
          final Edificio template = game.monumentosDisponibles[i];
          final String size = _getBuildingSizeCli(template);
          final String req = _monumentRequirementSummaryCli(template.id);
          final String typeTag = game.nombreTipoEdificio(template.type);
          print('  [$i] [$typeTag] ${template.name} - $size | $req');
        }
        print('  [-1] Cancelar');
        stdout.write('Elige monumento: ');
        final int? monIdx = int.tryParse(stdin.readLineSync() ?? '0');

        if (monIdx == null ||
            monIdx < 0 ||
            monIdx >= game.monumentosDisponibles.length) {
          if (monIdx == -1) {
            print('\n>> Construccion cancelada.');
          } else {
            print('\n!! Monumento no valido.');
          }
        } else {
          final Edificio selectedMon = game.monumentosDisponibles[monIdx];

          if (selectedMon.rotations.length == 1) {
            _intentarConstruir(game, origin, selectedMon, 0, monIdx, true);
          } else {
            print('\n--- ELIGE ORIENTACION ---');
            for (int r = 0; r < selectedMon.rotations.length; r++) {
              print('  [$r] ${selectedMon.rotationNames[r]}');
            }
            print('  [-1] Cancelar');
            stdout.write('Opcion: ');
            final int? rotIdx = int.tryParse(stdin.readLineSync() ?? '0');

            if (rotIdx == null ||
                rotIdx < 0 ||
                rotIdx >= selectedMon.rotations.length) {
              if (rotIdx == -1) {
                print('\n>> Construccion cancelada.');
              } else {
                print('\n!! Orientacion no valida.');
              }
            } else {
              _intentarConstruir(
                game,
                origin,
                selectedMon,
                rotIdx,
                monIdx,
                true,
              );
            }
          }
        }
      } else {
        final int? catIdx = int.tryParse(choiceEdificio ?? '0');

        if (catIdx == null ||
            catIdx < 0 ||
            catIdx >= currentPlayer.availableBuildings.length) {
          if (catIdx == -1) {
            print('\n>> Construccion cancelada.');
          } else {
            print('\n!! Edificio no valido.');
          }
        } else {
          final Edificio selected = currentPlayer.availableBuildings[catIdx];

          if (selected.rotations.length == 1) {
            _intentarConstruir(game, origin, selected, 0, catIdx, false);
          } else {
            print('\n--- ELIGE ORIENTACION ---');
            for (int r = 0; r < selected.rotations.length; r++) {
              print('  [$r] ${selected.rotationNames[r]}');
            }
            print('  [-1] Cancelar');
            stdout.write('Opcion: ');
            final int? rotIdx = int.tryParse(stdin.readLineSync() ?? '0');

            if (rotIdx == null ||
                rotIdx < 0 ||
                rotIdx >= selected.rotations.length) {
              if (rotIdx == -1) {
                print('\n>> Construccion cancelada.');
              } else {
                print('\n!! Orientacion no valida.');
              }
            } else {
              _intentarConstruir(game, origin, selected, rotIdx, catIdx, false);
            }
          }
        }
      }
    } else if (choice == '4') {
      try {
        saveFile.writeAsStringSync(game.toJsonString());
        print('Partida guardada en partida_guardada.json');
      } catch (e) {
        print('Error al guardar la partida: $e');
      }
    } else if (choice == '5') {
      try {
        if (!saveFile.existsSync()) {
          print('No se encontro el archivo de partida guardada.');
          continue;
        }
        game = Juego.fromJsonString(saveFile.readAsStringSync());
        print('Partida cargada exitosamente.');
      } catch (e) {
        print('Error al cargar la partida: $e');
      }
    } else if (choice == '0') {
      break;
    }
  }
}
