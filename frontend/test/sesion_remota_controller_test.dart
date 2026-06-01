import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:for_core/core.dart';
import 'package:for_core/protocol.dart';
import 'package:frontend/infrastructure/remote_session_store.dart';
import 'package:frontend/infrastructure/sesion_remota.dart';

void main() {
  test('crea sala remota usando alias de sala', () async {
    final List<String> paths = <String>[];
    final List<Map<String, dynamic>> joins = <Map<String, dynamic>>[];
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    unawaited(
      server.forEach((HttpRequest request) async {
        paths.add(request.uri.path);
        final WebSocket socket = await WebSocketTransformer.upgrade(request);
        socket.listen((dynamic rawMessage) {
          final Map<String, dynamic> message = ProtocoloRemoto.decodificarJson(
            rawMessage as String,
          );
          joins.add(message);
          socket.add(
            ProtocoloRemoto.codificarJson(
              JoinedMessage(
                gameId: 'game_0001',
                roomAlias: 'ROMA',
                sessionToken: 'token-sala',
                playerId: 0,
                playerName: 'ABC',
                game: Juego(3).toJson(includePendingSummary: false),
              ).toJson(),
            ),
          );
        });
      }),
    );

    final SesionRemotaController controller = SesionRemotaController(
      sessionStore: _FakeRemoteSessionStore(),
    );
    final String url = 'ws://127.0.0.1:${server.port}';

    try {
      await controller.unirse(
        url,
        playerName: 'abc',
        roomAlias: 'roma',
        createRoom: true,
        players: 3,
      );

      expect(paths.single, '/rooms/ROMA/ws');
      expect(joins.single[CampoMensaje.roomAlias], 'roma');
      expect(joins.single['createRoom'], isTrue);
      expect(joins.single['players'], 3);
      expect(controller.gameId, 'game_0001');
      expect(controller.sessionToken, 'token-sala');
    } finally {
      await controller.cerrar();
      await server.close(force: true);
    }
  });

  test('reutiliza sessionToken recordado despues de cerrar', () async {
    final List<Map<String, dynamic>> joins = <Map<String, dynamic>>[];
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    unawaited(
      server.forEach((HttpRequest request) async {
        final WebSocket socket = await WebSocketTransformer.upgrade(request);
        socket.listen((dynamic rawMessage) {
          final Map<String, dynamic> message = ProtocoloRemoto.decodificarJson(
            rawMessage as String,
          );
          if (ProtocoloRemoto.tipoDe(message) != TipoMensajeRemoto.join) {
            return;
          }

          joins.add(message);
          socket.add(
            ProtocoloRemoto.codificarJson(
              JoinedMessage(
                gameId: 'game_0001',
                sessionToken: 'token-recordado',
                playerId: 0,
                playerName: 'ABC',
                game: Juego(2).toJson(includePendingSummary: false),
              ).toJson(),
            ),
          );
        });
      }),
    );

    final SesionRemotaController controller = SesionRemotaController(
      sessionStore: _FakeRemoteSessionStore(),
    );
    final String url = 'ws://127.0.0.1:${server.port}/games/game_0001/ws';

    try {
      await controller.unirse(url, playerName: 'abc');
      expect(controller.sessionToken, 'token-recordado');

      await controller.cerrar();
      expect(controller.sessionToken, isNull);

      await controller.unirse(url, playerName: 'abc');

      expect(joins, hasLength(2));
      expect(joins.first[CampoMensaje.sessionToken], isNull);
      expect(joins.last[CampoMensaje.sessionToken], 'token-recordado');
      expect(joins.last[CampoMensaje.gameId], 'game_0001');
    } finally {
      await controller.cerrar();
      await server.close(force: true);
    }
  });

  test('reutiliza sessionToken recordado en otro controller', () async {
    final List<Map<String, dynamic>> joins = <Map<String, dynamic>>[];
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    unawaited(
      server.forEach((HttpRequest request) async {
        final WebSocket socket = await WebSocketTransformer.upgrade(request);
        socket.listen((dynamic rawMessage) {
          final Map<String, dynamic> message = ProtocoloRemoto.decodificarJson(
            rawMessage as String,
          );
          if (ProtocoloRemoto.tipoDe(message) != TipoMensajeRemoto.join) {
            return;
          }

          joins.add(message);
          socket.add(
            ProtocoloRemoto.codificarJson(
              JoinedMessage(
                gameId: 'game_0001',
                roomAlias: 'ROMA',
                sessionToken: 'token-compartido',
                playerId: 0,
                playerName: 'ABC',
                game: Juego(2).toJson(includePendingSummary: false),
              ).toJson(),
            ),
          );
        });
      }),
    );

    final String url = 'ws://127.0.0.1:${server.port}';
    final _FakeRemoteSessionStore store = _FakeRemoteSessionStore();
    final SesionRemotaController first = SesionRemotaController(
      sessionStore: store,
    );
    final SesionRemotaController second = SesionRemotaController(
      sessionStore: store,
    );

    try {
      await first.unirse(url, playerName: 'abc', roomAlias: 'roma');
      await first.cerrar();

      await second.unirse(url, playerName: 'abc', roomAlias: 'roma');

      expect(joins, hasLength(2));
      expect(joins.first[CampoMensaje.sessionToken], isNull);
      expect(joins.last[CampoMensaje.sessionToken], 'token-compartido');
      expect(
        joins.last[CampoMensaje.clientId],
        joins.first[CampoMensaje.clientId],
      );
      expect(joins.last[CampoMensaje.gameId], 'game_0001');
    } finally {
      await first.cerrar();
      await second.cerrar();
      await server.close(force: true);
    }
  });

  test('olvida sessionToken caducado y reintenta como sala nueva', () async {
    final List<Map<String, dynamic>> joins = <Map<String, dynamic>>[];
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    unawaited(
      server.forEach((HttpRequest request) async {
        final WebSocket socket = await WebSocketTransformer.upgrade(request);
        socket.listen((dynamic rawMessage) async {
          final Map<String, dynamic> message = ProtocoloRemoto.decodificarJson(
            rawMessage as String,
          );
          if (ProtocoloRemoto.tipoDe(message) != TipoMensajeRemoto.join) {
            return;
          }

          joins.add(message);
          final String? sessionToken = message[CampoMensaje.sessionToken]
              ?.toString();
          if (sessionToken == 'token-viejo') {
            socket.add(
              ProtocoloRemoto.codificarJson(
                const ErrorMessage(
                  message:
                      'La sesion ya no es valida para esta partida. Vuelve a entrar sin token.',
                ).toJson(),
              ),
            );
            await socket.close();
            return;
          }

          socket.add(
            ProtocoloRemoto.codificarJson(
              JoinedMessage(
                gameId: 'game_0001',
                sessionToken: joins.length == 1 ? 'token-viejo' : 'token-nuevo',
                playerId: 0,
                playerName: 'ABC',
                game: Juego(2).toJson(includePendingSummary: false),
              ).toJson(),
            ),
          );
        });
      }),
    );

    final SesionRemotaController controller = SesionRemotaController(
      sessionStore: _FakeRemoteSessionStore(),
    );
    final String url = 'ws://127.0.0.1:${server.port}/games/game_0001/ws';

    try {
      await controller.unirse(url, playerName: 'abc');
      expect(controller.sessionToken, 'token-viejo');

      await controller.cerrar();
      await controller.unirse(url, playerName: 'abc');

      expect(controller.sessionToken, 'token-nuevo');
      expect(joins, hasLength(3));
      expect(joins[1][CampoMensaje.sessionToken], 'token-viejo');
      expect(joins[2][CampoMensaje.sessionToken], isNull);
    } finally {
      await controller.cerrar();
      await server.close(force: true);
    }
  });

  test('muestra finalizacion remota como alerta de participantes', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    unawaited(
      server.forEach((HttpRequest request) async {
        final WebSocket socket = await WebSocketTransformer.upgrade(request);
        socket.listen((dynamic rawMessage) async {
          final Map<String, dynamic> message = ProtocoloRemoto.decodificarJson(
            rawMessage as String,
          );
          if (ProtocoloRemoto.tipoDe(message) != TipoMensajeRemoto.join) {
            return;
          }

          socket.add(
            ProtocoloRemoto.codificarJson(
              JoinedMessage(
                gameId: 'game_0001',
                sessionToken: 'token-finaliza',
                playerId: 0,
                playerName: 'ABC',
                game: Juego(2).toJson(includePendingSummary: false),
              ).toJson(),
            ),
          );
          socket.add(
            ProtocoloRemoto.codificarJson(
              const ErrorMessage(
                message:
                    'ABC lleva mas de 3 minutos desconectado. La partida remota ha sido finalizada.',
              ).toJson(),
            ),
          );
          await socket.close();
        });
      }),
    );

    final SesionRemotaController controller = SesionRemotaController(
      sessionStore: _FakeRemoteSessionStore(),
    );
    final String url = 'ws://127.0.0.1:${server.port}/games/game_0001/ws';

    try {
      await controller.unirse(url, playerName: 'abc');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.alertaParticipantes, contains('finalizada'));
      expect(controller.ultimoError, isNull);
    } finally {
      await controller.cerrar();
      await server.close(force: true);
    }
  });
}

class _FakeRemoteSessionStore implements RemoteSessionStore {
  String? clientId;
  final Map<String, String> sessions = <String, String>{};

  @override
  Future<void> deleteSession(String key) async {
    sessions.remove(key);
  }

  @override
  Future<String?> readClientId() async {
    return clientId;
  }

  @override
  Future<String?> readSession(String key) async {
    return sessions[key];
  }

  @override
  Future<void> writeClientId(String clientId) async {
    this.clientId = clientId;
  }

  @override
  Future<void> writeSession(String key, String value) async {
    sessions[key] = value;
  }
}
