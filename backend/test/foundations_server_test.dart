import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:for_core/core.dart';
import 'package:for_core/protocol.dart';
import 'package:for_server/foundations_server.dart';
import 'package:for_server/persistence/partida_repository.dart';
import 'package:for_server/persistence/ranking_repository.dart';
import 'package:test/test.dart';

class _RankingGlobalEnMemoria implements RankingRepository {
  final Map<String, int> _puntuaciones = <String, int>{};

  @override
  Future<List<EntradaClasificacion>> cargarTop10() async {
    final List<EntradaClasificacion> entradas = await cargarRankingCompleto();
    return entradas.take(10).toList(growable: false);
  }

  @override
  Future<List<EntradaClasificacion>> cargarRankingCompleto() async {
    final List<EntradaClasificacion> entradas =
        _puntuaciones.entries
            .map(
              (MapEntry<String, int> entry) => EntradaClasificacion(
                alias: entry.key,
                puntuacion: entry.value,
              ),
            )
            .toList()
          ..sort(
            (EntradaClasificacion a, EntradaClasificacion b) =>
                b.puntuacion.compareTo(a.puntuacion),
          );
    return entradas;
  }

  @override
  Future<void> close() async {}

  @override
  Future<bool> registrarPuntuacionMaxima({
    required String alias,
    required int puntuacion,
  }) async {
    final int? actual = _puntuaciones[alias];
    if (actual != null && actual >= puntuacion) {
      return false;
    }
    _puntuaciones[alias] = puntuacion;
    return true;
  }
}

void main() {
  group('FoundationsServer', () {
    late _RankingGlobalEnMemoria ranking;
    late PartidaRepositoryEnMemoria partidas;
    late FoundationsServer server;
    late Uri baseUri;

    setUp(() async {
      ranking = _RankingGlobalEnMemoria();
      partidas = PartidaRepositoryEnMemoria();
      server = FoundationsServer(
        defaultPlayerCount: 2,
        rankingGlobal: ranking,
        partidaStore: partidas,
        descripcionRanking: 'Ranking en memoria',
        disconnectedGracePeriod: const Duration(milliseconds: 100),
      );

      unawaited(
        server.start(host: InternetAddress.loopbackIPv4.address, port: 0),
      );
      await _esperarServidor(server);
      baseUri = Uri.parse('http://127.0.0.1:${server.boundPort}');
    });

    tearDown(() async {
      await server.close();
    });

    test('expone health, crea varias partidas y las lista', () async {
      final Map<String, dynamic> health = await _getJson(
        baseUri.resolve('/health'),
      );
      expect(health['status'], 'ok');
      expect(health['rooms'], 0);

      final Map<String, dynamic> primera = await _postJson(
        baseUri.resolve('/games'),
        <String, dynamic>{'players': 3},
      );
      final Map<String, dynamic> segunda = await _postJson(
        baseUri.resolve('/games'),
        <String, dynamic>{'players': 4},
      );

      expect(primera['wsPath'], '/games/game_0001/ws');
      expect(segunda['wsPath'], '/games/game_0002/ws');

      final Map<String, dynamic> listado = await _getJson(
        baseUri.resolve('/games'),
      );
      final List<dynamic> games = listado['games'] as List<dynamic>;
      expect(games.map((dynamic game) => game[CampoMensaje.gameId]), <String>[
        'game_0001',
        'game_0002',
      ]);
    });

    test('crea sala con alias unico y permite entrar por alias', () async {
      final Map<String, dynamic> creada = await _postJson(
        baseUri.resolve('/games'),
        <String, dynamic>{'players': 3, CampoMensaje.roomAlias: 'roma'},
      );
      expect(creada['wsPath'], '/rooms/ROMA/ws');
      expect((creada['game'] as Map)[CampoMensaje.roomAlias], 'ROMA');

      final _JsonResponse duplicada = await _postJsonResponse(
        baseUri.resolve('/games'),
        <String, dynamic>{'players': 2, CampoMensaje.roomAlias: 'ROMA'},
      );
      expect(duplicada.statusCode, HttpStatus.badRequest);
      expect(duplicada.body['error'], contains('ya existe'));

      final WebSocket socket = await _connectWs(baseUri, '/rooms/roma/ws');
      final StreamIterator<Map<String, dynamic>> queue = _jsonQueue(socket);
      socket.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'abc').toJson(),
        ),
      );

      final Map<String, dynamic> joined = await _nextType(
        queue,
        TipoMensajeRemoto.joined,
      );
      expect(joined[CampoMensaje.gameId], 'game_0001');
      expect(joined[CampoMensaje.roomAlias], 'ROMA');

      await queue.cancel();
      await socket.close();
      await _waitForRoomCount(baseUri, 0);

      final Map<String, dynamic> recreada = await _postJson(
        baseUri.resolve('/games'),
        <String, dynamic>{'players': 2, CampoMensaje.roomAlias: 'ROMA'},
      );
      expect(recreada['wsPath'], '/rooms/ROMA/ws');
      expect((recreada['game'] as Map)[CampoMensaje.gameId], 'game_0001');
    });

    test('primer jugador puede crear sala por WebSocket con alias', () async {
      final WebSocket socketA = await _connectWs(baseUri, '/rooms/casa/ws');
      final StreamIterator<Map<String, dynamic>> queueA = _jsonQueue(socketA);
      socketA.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(
            playerName: 'abc',
            roomAlias: 'casa',
            createRoom: true,
            players: 3,
          ).toJson(),
        ),
      );

      final Map<String, dynamic> joinedA = await _nextType(
        queueA,
        TipoMensajeRemoto.joined,
      );
      expect(joinedA[CampoMensaje.gameId], 'game_0001');
      expect(joinedA[CampoMensaje.roomAlias], 'CASA');

      final WebSocket socketB = await _connectWs(baseUri, '/rooms/CASA/ws');
      final StreamIterator<Map<String, dynamic>> queueB = _jsonQueue(socketB);
      socketB.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'rom').toJson(),
        ),
      );
      final Map<String, dynamic> joinedB = await _nextType(
        queueB,
        TipoMensajeRemoto.joined,
      );
      expect(joinedB[CampoMensaje.gameId], 'game_0001');
      expect(joinedB[CampoMensaje.roomAlias], 'CASA');
      expect(joinedB[CampoMensaje.playerId], 1);

      final WebSocket socketDuplicado = await _connectWs(
        baseUri,
        '/rooms/CASA/ws',
      );
      final StreamIterator<Map<String, dynamic>> queueDuplicado = _jsonQueue(
        socketDuplicado,
      );
      socketDuplicado.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(
            playerName: 'dup',
            roomAlias: 'CASA',
            createRoom: true,
            players: 2,
          ).toJson(),
        ),
      );
      final Map<String, dynamic> errorDuplicado = await _nextType(
        queueDuplicado,
        TipoMensajeRemoto.error,
      );
      expect(errorDuplicado[CampoMensaje.message], contains('ya existe'));

      await queueA.cancel();
      await queueB.cancel();
      await queueDuplicado.cancel();
      await socketA.close();
      await socketB.close();
      await socketDuplicado.close();
    });

    test(
      'permite reconectar con token aunque el cliente envie createRoom',
      () async {
        final WebSocket socket = await _connectWs(baseUri, '/rooms/roma/ws');
        final StreamIterator<Map<String, dynamic>> queue = _jsonQueue(socket);
        socket.add(
          ProtocoloRemoto.codificarJson(
            const JoinRequest(
              playerName: 'abc',
              roomAlias: 'roma',
              createRoom: true,
              players: 2,
            ).toJson(),
          ),
        );
        final Map<String, dynamic> joined = await _nextType(
          queue,
          TipoMensajeRemoto.joined,
        );
        final String token = joined[CampoMensaje.sessionToken] as String;

        await queue.cancel();
        await socket.close();
        await _waitForConnectedPlayers(baseUri, 'game_0001', 0);

        final WebSocket reconnectedSocket = await _connectWs(
          baseUri,
          '/rooms/roma/ws',
        );
        final StreamIterator<Map<String, dynamic>> reconnectedQueue =
            _jsonQueue(reconnectedSocket);
        reconnectedSocket.add(
          ProtocoloRemoto.codificarJson(
            JoinRequest(
              playerName: 'abc',
              roomAlias: 'roma',
              createRoom: true,
              players: 2,
              sessionToken: token,
            ).toJson(),
          ),
        );

        final Map<String, dynamic> rejoined = await _nextType(
          reconnectedQueue,
          TipoMensajeRemoto.joined,
        );
        expect(rejoined[CampoMensaje.sessionToken], token);
        expect(rejoined[CampoMensaje.playerId], 0);

        await reconnectedQueue.cancel();
        await reconnectedSocket.close();
      },
    );

    test('no deja sala reservada si falla token al crear por alias', () async {
      final WebSocket socket = await _connectWs(baseUri, '/rooms/otra/ws');
      final StreamIterator<Map<String, dynamic>> queue = _jsonQueue(socket);
      socket.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(
            playerName: 'abc',
            roomAlias: 'OTRA',
            createRoom: true,
            players: 2,
            sessionToken: 'token-de-otra-partida',
          ).toJson(),
        ),
      );

      final Map<String, dynamic> error = await _nextType(
        queue,
        TipoMensajeRemoto.error,
      );
      expect(error[CampoMensaje.message], contains('sesion ya no es valida'));

      await queue.cancel();
      await socket.close();
      await _waitForRoomCount(baseUri, 0);

      final WebSocket nuevoSocket = await _connectWs(baseUri, '/rooms/OTRA/ws');
      final StreamIterator<Map<String, dynamic>> nuevaQueue = _jsonQueue(
        nuevoSocket,
      );
      nuevoSocket.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(
            playerName: 'abc',
            roomAlias: 'OTRA',
            createRoom: true,
            players: 2,
          ).toJson(),
        ),
      );
      final Map<String, dynamic> joined = await _nextType(
        nuevaQueue,
        TipoMensajeRemoto.joined,
      );
      expect(joined[CampoMensaje.roomAlias], 'OTRA');

      await nuevaQueue.cancel();
      await nuevoSocket.close();
    });

    test('rechaza creacion de partida con numero invalido', () async {
      final _JsonResponse response = await _postJsonResponse(
        baseUri.resolve('/games'),
        <String, dynamic>{'players': 9},
      );

      expect(response.statusCode, HttpStatus.badRequest);
      expect(response.body['error'], contains('entre 2 y 5'));
    });

    test('rechaza cuerpo JSON invalido al crear partida', () async {
      final _JsonResponse response = await _postRawJsonResponse(
        baseUri.resolve('/games'),
        '[',
      );

      expect(response.statusCode, HttpStatus.badRequest);
      expect(response.body['error'], isNotEmpty);
    });

    test('permite cerrar una sala por HTTP', () async {
      await _postJson(baseUri.resolve('/games'), <String, dynamic>{
        'players': 2,
        CampoMensaje.roomAlias: 'CIERRE',
      });

      final _JsonResponse closed = await _deleteJsonResponse(
        baseUri.resolve('/games/CIERRE'),
      );

      expect(closed.statusCode, HttpStatus.ok);
      expect(closed.body['closed'], isTrue);
      expect(closed.body[CampoMensaje.gameId], 'game_0001');

      final Map<String, dynamic> listado = await _getJson(
        baseUri.resolve('/games'),
      );
      expect(listado['games'], isEmpty);
    });

    test('devuelve leaderboard por HTTP', () async {
      await ranking.registrarPuntuacionMaxima(alias: 'ROM', puntuacion: 20);

      final Map<String, dynamic> response = await _getJson(
        baseUri.resolve('/leaderboard'),
      );
      final List<dynamic> entries = response['entries'] as List<dynamic>;
      expect(entries.single['alias'], 'ROM');
      expect(entries.single['puntuacion'], 20);
    });

    test('permite unirse y reconectar con el mismo sessionToken', () async {
      final WebSocket socket = await _connectWs(baseUri, '/games/game_0001/ws');
      final StreamIterator<Map<String, dynamic>> queue = _jsonQueue(socket);
      socket.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'abc').toJson(),
        ),
      );

      final Map<String, dynamic> joined = await _nextType(
        queue,
        TipoMensajeRemoto.joined,
      );
      final String token = joined[CampoMensaje.sessionToken] as String;
      expect(joined[CampoMensaje.gameId], 'game_0001');
      expect(joined[CampoMensaje.playerId], 0);
      expect(joined[CampoMensaje.playerName], 'ABC');
      expect(token, isNotEmpty);

      final WebSocket reconnectedSocket = await _connectWs(
        baseUri,
        '/games/game_0001/ws',
      );
      final StreamIterator<Map<String, dynamic>> reconnectedQueue = _jsonQueue(
        reconnectedSocket,
      );
      reconnectedSocket.add(
        ProtocoloRemoto.codificarJson(
          JoinRequest(playerName: 'abc', sessionToken: token).toJson(),
        ),
      );

      final Map<String, dynamic> rejoined = await _nextType(
        reconnectedQueue,
        TipoMensajeRemoto.joined,
      );
      expect(rejoined[CampoMensaje.sessionToken], token);
      expect(rejoined[CampoMensaje.playerId], 0);
      expect(rejoined[CampoMensaje.playerName], 'ABC');

      await queue.cancel();
      await reconnectedQueue.cancel();
      await socket.close();
      await reconnectedSocket.close();
    });

    test('mantiene sessionToken tras desconexion breve', () async {
      final WebSocket socket = await _connectWs(baseUri, '/games/game_0001/ws');
      final StreamIterator<Map<String, dynamic>> queue = _jsonQueue(socket);
      socket.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'abc').toJson(),
        ),
      );

      final Map<String, dynamic> joined = await _nextType(
        queue,
        TipoMensajeRemoto.joined,
      );
      final String token = joined[CampoMensaje.sessionToken] as String;

      await queue.cancel();
      await socket.close();
      await _waitForConnectedPlayers(baseUri, 'game_0001', 0);

      final WebSocket reconnectedSocket = await _connectWs(
        baseUri,
        '/games/game_0001/ws',
      );
      final StreamIterator<Map<String, dynamic>> reconnectedQueue = _jsonQueue(
        reconnectedSocket,
      );
      reconnectedSocket.add(
        ProtocoloRemoto.codificarJson(
          JoinRequest(playerName: 'abc', sessionToken: token).toJson(),
        ),
      );

      final Map<String, dynamic> rejoined = await _nextType(
        reconnectedQueue,
        TipoMensajeRemoto.joined,
      );
      expect(rejoined[CampoMensaje.sessionToken], token);
      expect(rejoined[CampoMensaje.playerId], 0);

      await reconnectedQueue.cancel();
      await reconnectedSocket.close();
    });

    test('rechaza sessionToken desde otro terminal', () async {
      final WebSocket socket = await _connectWs(baseUri, '/games/game_0001/ws');
      final StreamIterator<Map<String, dynamic>> queue = _jsonQueue(socket);
      socket.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(
            playerName: 'abc',
            clientId: 'terminal-original',
          ).toJson(),
        ),
      );

      final Map<String, dynamic> joined = await _nextType(
        queue,
        TipoMensajeRemoto.joined,
      );
      final String token = joined[CampoMensaje.sessionToken] as String;

      await queue.cancel();
      await socket.close();
      await _waitForConnectedPlayers(baseUri, 'game_0001', 0);

      final WebSocket otherSocket = await _connectWs(
        baseUri,
        '/games/game_0001/ws',
      );
      final StreamIterator<Map<String, dynamic>> otherQueue = _jsonQueue(
        otherSocket,
      );
      otherSocket.add(
        ProtocoloRemoto.codificarJson(
          JoinRequest(
            playerName: 'abc',
            sessionToken: token,
            clientId: 'otro-terminal',
          ).toJson(),
        ),
      );

      final Map<String, dynamic> error = await _nextType(
        otherQueue,
        TipoMensajeRemoto.error,
      );
      expect(error[CampoMensaje.message], contains('otro terminal'));

      await otherQueue.cancel();
      await otherSocket.close();
    });

    test(
      'suspende la sala si un jugador supera el tiempo de reconexion',
      () async {
        final WebSocket socketA = await _connectWs(
          baseUri,
          '/games/game_0001/ws',
        );
        final WebSocket socketB = await _connectWs(
          baseUri,
          '/games/game_0001/ws',
        );
        final StreamIterator<Map<String, dynamic>> queueA = _jsonQueue(socketA);
        final StreamIterator<Map<String, dynamic>> queueB = _jsonQueue(socketB);

        socketA.add(
          ProtocoloRemoto.codificarJson(
            const JoinRequest(playerName: 'aaa').toJson(),
          ),
        );
        socketB.add(
          ProtocoloRemoto.codificarJson(
            const JoinRequest(playerName: 'bbb').toJson(),
          ),
        );

        await _nextType(queueA, TipoMensajeRemoto.joined);
        await _nextType(queueB, TipoMensajeRemoto.joined);

        await queueA.cancel();
        await socketA.close();

        final Map<String, dynamic> error = await _nextType(
          queueB,
          TipoMensajeRemoto.error,
        );
        expect(error[CampoMensaje.message], contains('AAA'));
        expect(error[CampoMensaje.message], contains('finalizada'));

        await queueB.cancel();
        await socketB.close();
        await _waitForRoomCount(baseUri, 0);
      },
    );

    test('exige sessionToken para recuperar plaza en sala llena', () async {
      final WebSocket socketA = await _connectWs(
        baseUri,
        '/games/game_0001/ws',
      );
      final WebSocket socketB = await _connectWs(
        baseUri,
        '/games/game_0001/ws',
      );
      final StreamIterator<Map<String, dynamic>> queueA = _jsonQueue(socketA);
      final StreamIterator<Map<String, dynamic>> queueB = _jsonQueue(socketB);

      socketA.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'abc').toJson(),
        ),
      );
      socketB.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'rom').toJson(),
        ),
      );

      final Map<String, dynamic> joinedA = await _nextType(
        queueA,
        TipoMensajeRemoto.joined,
      );
      await _nextType(queueB, TipoMensajeRemoto.joined);
      final String tokenA = joinedA[CampoMensaje.sessionToken] as String;
      expect(joinedA[CampoMensaje.playerId], 0);

      await queueA.cancel();
      await socketA.close();
      await _waitForConnectedPlayers(baseUri, 'game_0001', 1);

      final WebSocket socketSinToken = await _connectWs(
        baseUri,
        '/games/game_0001/ws',
      );
      final StreamIterator<Map<String, dynamic>> queueSinToken = _jsonQueue(
        socketSinToken,
      );
      socketSinToken.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'abc').toJson(),
        ),
      );
      final Map<String, dynamic> errorSinToken = await _nextType(
        queueSinToken,
        TipoMensajeRemoto.error,
      );
      expect(errorSinToken[CampoMensaje.message], contains('ocupado'));

      await queueSinToken.cancel();
      await socketSinToken.close();

      final WebSocket socketA2 = await _connectWs(
        baseUri,
        '/games/game_0001/ws',
      );
      final StreamIterator<Map<String, dynamic>> queueA2 = _jsonQueue(socketA2);
      socketA2.add(
        ProtocoloRemoto.codificarJson(
          JoinRequest(playerName: 'abc', sessionToken: tokenA).toJson(),
        ),
      );

      final Map<String, dynamic> rejoinedA = await _nextType(
        queueA2,
        TipoMensajeRemoto.joined,
      );
      expect(rejoinedA[CampoMensaje.playerId], 0);
      expect(rejoinedA[CampoMensaje.playerName], 'ABC');

      await queueA2.cancel();
      await queueB.cancel();
      await socketA2.close();
      await socketB.close();
    });

    test('reutiliza game_0001 como sala limpia cuando queda vacia', () async {
      final WebSocket socket = await _connectWs(baseUri, '/games/game_0001/ws');
      final StreamIterator<Map<String, dynamic>> queue = _jsonQueue(socket);
      socket.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'abc').toJson(),
        ),
      );
      final Map<String, dynamic> joined = await _nextType(
        queue,
        TipoMensajeRemoto.joined,
      );
      final String tokenAnterior = joined[CampoMensaje.sessionToken] as String;

      await queue.cancel();
      await socket.close();
      await _waitForRoomCount(baseUri, 0);

      final WebSocket socketTokenAntiguo = await _connectWs(
        baseUri,
        '/games/game_0001/ws',
      );
      final StreamIterator<Map<String, dynamic>> queueTokenAntiguo = _jsonQueue(
        socketTokenAntiguo,
      );
      socketTokenAntiguo.add(
        ProtocoloRemoto.codificarJson(
          JoinRequest(playerName: 'abc', sessionToken: tokenAnterior).toJson(),
        ),
      );
      final Map<String, dynamic> errorTokenAntiguo = await _nextType(
        queueTokenAntiguo,
        TipoMensajeRemoto.error,
      );
      expect(
        errorTokenAntiguo[CampoMensaje.message],
        contains('sesion ya no es valida'),
      );

      await queueTokenAntiguo.cancel();
      await socketTokenAntiguo.close();

      final WebSocket socketNuevo = await _connectWs(
        baseUri,
        '/games/game_0001/ws',
      );
      final StreamIterator<Map<String, dynamic>> queueNuevo = _jsonQueue(
        socketNuevo,
      );
      socketNuevo.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'abc').toJson(),
        ),
      );

      final Map<String, dynamic> joinedNuevo = await _nextType(
        queueNuevo,
        TipoMensajeRemoto.joined,
      );
      expect(joinedNuevo[CampoMensaje.gameId], 'game_0001');
      expect(joinedNuevo[CampoMensaje.playerId], 0);
      expect(joinedNuevo[CampoMensaje.sessionToken], isNot(tokenAnterior));

      await queueNuevo.cancel();
      await socketNuevo.close();
    });

    test('acepta una accion valida y persiste evento y snapshot', () async {
      final WebSocket socket = await _connectWs(baseUri, '/games/game_0001/ws');
      final StreamIterator<Map<String, dynamic>> queue = _jsonQueue(socket);
      socket.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'rom').toJson(),
        ),
      );
      await _nextType(queue, TipoMensajeRemoto.joined);

      socket.add(
        ProtocoloRemoto.codificarJson(
          const ActionRequest(
            requestId: 'req-income-1',
            action: TipoAccionRemota.income,
          ).toJson(),
        ),
      );

      final Map<String, dynamic> accepted = await _nextType(
        queue,
        TipoMensajeRemoto.actionAccepted,
      );
      expect(accepted[CampoMensaje.requestId], 'req-income-1');
      expect(
        partidas.eventos.any(
          (Map<String, dynamic> evento) =>
              evento[CampoMensaje.gameId] == 'game_0001' &&
              evento['tipo'] == TipoAccionRemota.income,
        ),
        isTrue,
      );
      expect(partidas.snapshots['game_0001'], isNotNull);

      await queue.cancel();
      await socket.close();
    });

    test(
      'rechaza una accion fuera de turno manteniendo el requestId',
      () async {
        final WebSocket socketA = await _connectWs(
          baseUri,
          '/games/game_0001/ws',
        );
        final WebSocket socketB = await _connectWs(
          baseUri,
          '/games/game_0001/ws',
        );
        final StreamIterator<Map<String, dynamic>> queueA = _jsonQueue(socketA);
        final StreamIterator<Map<String, dynamic>> queueB = _jsonQueue(socketB);

        socketA.add(
          ProtocoloRemoto.codificarJson(
            const JoinRequest(playerName: 'aaa').toJson(),
          ),
        );
        socketB.add(
          ProtocoloRemoto.codificarJson(
            const JoinRequest(playerName: 'bbb').toJson(),
          ),
        );

        await _nextType(queueA, TipoMensajeRemoto.joined);
        await _nextType(queueB, TipoMensajeRemoto.joined);

        socketB.add(
          ProtocoloRemoto.codificarJson(
            const ActionRequest(
              requestId: 'req-wrong-turn',
              action: TipoAccionRemota.income,
            ).toJson(),
          ),
        );

        final Map<String, dynamic> rejected = await _nextType(
          queueB,
          TipoMensajeRemoto.actionRejected,
        );
        expect(rejected[CampoMensaje.requestId], 'req-wrong-turn');
        expect(rejected[CampoMensaje.message], 'No es tu turno.');

        await queueA.cancel();
        await queueB.cancel();
        await socketA.close();
        await socketB.close();
      },
    );

    test('rechaza alias duplicado y sala llena', () async {
      final WebSocket socketA = await _connectWs(
        baseUri,
        '/games/game_0001/ws',
      );
      final WebSocket socketB = await _connectWs(
        baseUri,
        '/games/game_0001/ws',
      );
      final StreamIterator<Map<String, dynamic>> queueA = _jsonQueue(socketA);
      final StreamIterator<Map<String, dynamic>> queueB = _jsonQueue(socketB);

      socketA.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'dup').toJson(),
        ),
      );
      await _nextType(queueA, TipoMensajeRemoto.joined);

      socketB.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'dup').toJson(),
        ),
      );
      final Map<String, dynamic> duplicateError = await _nextType(
        queueB,
        TipoMensajeRemoto.error,
      );
      expect(duplicateError[CampoMensaje.message], contains('ya esta ocupado'));

      await queueA.cancel();
      await queueB.cancel();
      await socketA.close();
      await socketB.close();
      await _waitForRoomCount(baseUri, 0);

      final Map<String, dynamic> nueva = await _postJson(
        baseUri.resolve('/games'),
        <String, dynamic>{'players': 2},
      );
      final String wsPath = nueva['wsPath'] as String;
      final WebSocket one = await _connectWs(baseUri, wsPath);
      final WebSocket two = await _connectWs(baseUri, wsPath);
      final WebSocket three = await _connectWs(baseUri, wsPath);
      final StreamIterator<Map<String, dynamic>> q1 = _jsonQueue(one);
      final StreamIterator<Map<String, dynamic>> q2 = _jsonQueue(two);
      final StreamIterator<Map<String, dynamic>> q3 = _jsonQueue(three);

      one.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'aaa').toJson(),
        ),
      );
      two.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'bbb').toJson(),
        ),
      );
      three.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'ccc').toJson(),
        ),
      );

      await _nextType(q1, TipoMensajeRemoto.joined);
      await _nextType(q2, TipoMensajeRemoto.joined);
      final Map<String, dynamic> fullError = await _nextType(
        q3,
        TipoMensajeRemoto.error,
      );
      expect(fullError[CampoMensaje.message], contains('completa'));

      await q1.cancel();
      await q2.cancel();
      await q3.cancel();
      await one.close();
      await two.close();
      await three.close();
    });
  });

  test('arranca sala limpia aunque existan snapshots antiguos', () async {
    final _RankingGlobalEnMemoria ranking = _RankingGlobalEnMemoria();
    final PartidaRepositoryEnMemoria partidas = PartidaRepositoryEnMemoria();
    partidas.snapshots['game_0009'] = Juego(
      2,
    ).toJson(includePendingSummary: false);
    final FoundationsServer server = FoundationsServer(
      defaultPlayerCount: 2,
      rankingGlobal: ranking,
      partidaStore: partidas,
      descripcionRanking: 'Ranking en memoria',
      disconnectedGracePeriod: const Duration(milliseconds: 100),
    );
    unawaited(
      server.start(host: InternetAddress.loopbackIPv4.address, port: 0),
    );
    await _esperarServidor(server);
    final Uri baseUri = Uri.parse('http://127.0.0.1:${server.boundPort}');

    try {
      final Map<String, dynamic> listado = await _getJson(
        baseUri.resolve('/games'),
      );
      final List<dynamic> games = listado['games'] as List<dynamic>;
      expect(games, isEmpty);

      final Map<String, dynamic> creada = await _postJson(
        baseUri.resolve('/games'),
        <String, dynamic>{'players': 2},
      );
      expect(creada['wsPath'], '/games/game_0001/ws');
    } finally {
      await server.close();
    }
  });

  test(
    'restaura snapshots antiguos solo cuando se activa restoreRoomsOnStart',
    () async {
      final _RankingGlobalEnMemoria ranking = _RankingGlobalEnMemoria();
      final PartidaRepositoryEnMemoria partidas = PartidaRepositoryEnMemoria();
      partidas.snapshots['game_0009'] = Juego(
        2,
      ).toJson(includePendingSummary: false);
      final FoundationsServer server = FoundationsServer(
        defaultPlayerCount: 2,
        rankingGlobal: ranking,
        partidaStore: partidas,
        descripcionRanking: 'Ranking en memoria',
        restoreRoomsOnStart: true,
        disconnectedGracePeriod: const Duration(milliseconds: 100),
      );
      unawaited(
        server.start(host: InternetAddress.loopbackIPv4.address, port: 0),
      );
      await _esperarServidor(server);
      final Uri baseUri = Uri.parse('http://127.0.0.1:${server.boundPort}');

      try {
        final Map<String, dynamic> listado = await _getJson(
          baseUri.resolve('/games'),
        );
        final List<dynamic> games = listado['games'] as List<dynamic>;
        expect(games, hasLength(1));
        expect(games.single[CampoMensaje.gameId], 'game_0009');

        final Map<String, dynamic> creada = await _postJson(
          baseUri.resolve('/games'),
          <String, dynamic>{'players': 2},
        );
        expect(creada['wsPath'], '/games/game_0010/ws');
      } finally {
        await server.close();
      }
    },
  );

  test('exige access token cuando esta configurado', () async {
    final FoundationsServer server = FoundationsServer(
      defaultPlayerCount: 2,
      rankingGlobal: _RankingGlobalEnMemoria(),
      partidaStore: PartidaRepositoryEnMemoria(),
      descripcionRanking: 'Ranking en memoria',
      accessToken: 'casa-token',
      disconnectedGracePeriod: const Duration(milliseconds: 100),
    );
    unawaited(
      server.start(host: InternetAddress.loopbackIPv4.address, port: 0),
    );
    await _esperarServidor(server);
    final Uri baseUri = Uri.parse('http://127.0.0.1:${server.boundPort}');

    try {
      final _JsonResponse rejected = await _postJsonResponse(
        baseUri.resolve('/games'),
        <String, dynamic>{'players': 2},
      );
      expect(rejected.statusCode, HttpStatus.unauthorized);

      final _JsonResponse accepted = await _postJsonResponse(
        baseUri.resolve('/games?token=casa-token'),
        <String, dynamic>{'players': 2},
      );
      expect(accepted.statusCode, HttpStatus.created);

      final _JsonResponse acceptedByHeader = await _postJsonResponse(
        baseUri.resolve('/games'),
        <String, dynamic>{'players': 2},
        authorizationBearer: 'casa-token',
      );
      expect(acceptedByHeader.statusCode, HttpStatus.created);

      final WebSocket socket = await _connectWs(baseUri, '/games/game_0001/ws');
      final StreamIterator<Map<String, dynamic>> queue = _jsonQueue(socket);
      socket.add(
        ProtocoloRemoto.codificarJson(
          const JoinRequest(playerName: 'tok').toJson(),
        ),
      );
      final Map<String, dynamic> error = await _nextType(
        queue,
        TipoMensajeRemoto.error,
      );
      expect(error[CampoMensaje.message], contains('Token'));
      await queue.cancel();
      await socket.close();
    } finally {
      await server.close();
    }
  });
}

Future<void> _esperarServidor(FoundationsServer server) async {
  final DateTime limite = DateTime.now().add(const Duration(seconds: 5));
  while (server.boundPort == null) {
    if (DateTime.now().isAfter(limite)) {
      fail('El servidor no arranco a tiempo.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<Map<String, dynamic>> _getJson(Uri uri) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest request = await client.getUrl(uri);
    final HttpClientResponse response = await request.close();
    return await _decodeJsonResponse(response);
  } finally {
    client.close(force: true);
  }
}

Future<void> _waitForConnectedPlayers(
  Uri baseUri,
  String gameId,
  int expected,
) async {
  final DateTime limite = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(limite)) {
    final Map<String, dynamic> response = await _getJson(
      baseUri.resolve('/games/$gameId'),
    );
    final Map<String, dynamic> game = (response['game'] as Map)
        .cast<String, dynamic>();
    if (game['connectedPlayers'] == expected) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('No se alcanzo connectedPlayers=$expected para $gameId.');
}

Future<void> _waitForRoomCount(Uri baseUri, int expected) async {
  final DateTime limite = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(limite)) {
    final Map<String, dynamic> response = await _getJson(
      baseUri.resolve('/games'),
    );
    final List<dynamic> games = response['games'] as List<dynamic>;
    if (games.length == expected) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('No se alcanzo rooms=$expected.');
}

Future<Map<String, dynamic>> _postJson(
  Uri uri,
  Map<String, dynamic> body,
) async {
  return (await _postJsonResponse(uri, body)).body;
}

Future<_JsonResponse> _postJsonResponse(
  Uri uri,
  Map<String, dynamic> body, {
  String? authorizationBearer,
}) async {
  return _postRawJsonResponse(
    uri,
    jsonEncode(body),
    authorizationBearer: authorizationBearer,
  );
}

Future<_JsonResponse> _postRawJsonResponse(
  Uri uri,
  String body, {
  String? authorizationBearer,
}) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    if (authorizationBearer != null) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $authorizationBearer',
      );
    }
    request.write(body);
    final HttpClientResponse response = await request.close();
    return _JsonResponse(
      statusCode: response.statusCode,
      body: await _decodeJsonResponse(response),
    );
  } finally {
    client.close(force: true);
  }
}

Future<_JsonResponse> _deleteJsonResponse(Uri uri) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest request = await client.deleteUrl(uri);
    final HttpClientResponse response = await request.close();
    return _JsonResponse(
      statusCode: response.statusCode,
      body: await _decodeJsonResponse(response),
    );
  } finally {
    client.close(force: true);
  }
}

class _JsonResponse {
  const _JsonResponse({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, dynamic> body;
}

Future<Map<String, dynamic>> _decodeJsonResponse(
  HttpClientResponse response,
) async {
  final String body = await utf8.decoder.bind(response).join();
  return (jsonDecode(body) as Map).cast<String, dynamic>();
}

Future<WebSocket> _connectWs(Uri baseUri, String path) {
  return WebSocket.connect('ws://${baseUri.host}:${baseUri.port}$path');
}

StreamIterator<Map<String, dynamic>> _jsonQueue(WebSocket socket) {
  return StreamIterator<Map<String, dynamic>>(
    socket.map(
      (dynamic data) => ProtocoloRemoto.decodificarJson(data as String),
    ),
  );
}

Future<Map<String, dynamic>> _nextType(
  StreamIterator<Map<String, dynamic>> queue,
  String type,
) async {
  final DateTime limite = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(limite)) {
    final bool hasMessage = await queue.moveNext().timeout(
      const Duration(seconds: 5),
    );
    if (!hasMessage) {
      break;
    }
    final Map<String, dynamic> message = queue.current;
    if (ProtocoloRemoto.tipoDe(message) == type) {
      return message;
    }
  }
  fail('No llego ningun mensaje de tipo $type.');
}
