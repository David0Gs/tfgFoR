import 'package:for_core/core.dart';
import 'package:for_core/protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ProtocoloRemoto', () {
    test('serializa join request con token opcional', () {
      final Map<String, dynamic> json = const JoinRequest(
        playerName: 'ABC',
        gameId: 'game_0001',
        roomAlias: 'ROMA',
        createRoom: true,
        players: 3,
        sessionToken: 'token-1',
        clientId: 'terminal-1',
        accessToken: 'server-token',
      ).toJson();

      expect(json[CampoMensaje.version], ProtocoloRemoto.versionActual);
      expect(json[CampoMensaje.type], TipoMensajeRemoto.join);
      expect(json[CampoMensaje.gameId], 'game_0001');
      expect(json[CampoMensaje.roomAlias], 'ROMA');
      expect(json['createRoom'], isTrue);
      expect(json['players'], 3);
      expect(json[CampoMensaje.sessionToken], 'token-1');
      expect(json[CampoMensaje.clientId], 'terminal-1');
      expect(json[CampoMensaje.accessToken], 'server-token');
      expect(json[CampoMensaje.playerName], 'ABC');
    });

    test('parsea action request con payload', () {
      final ActionRequest request = ActionRequest.fromJson(<String, dynamic>{
        CampoMensaje.type: TipoMensajeRemoto.action,
        CampoMensaje.requestId: 'build-1',
        CampoMensaje.action: TipoAccionRemota.build,
        CampoMensaje.payload: <String, dynamic>{
          'originCoord': 'A1',
          'templateId': 'domus_i',
        },
      });

      expect(request.requestId, 'build-1');
      expect(request.action, TipoAccionRemota.build);
      expect(request.payload['originCoord'], 'A1');
    });

    test('serializa y parsea leaderboard', () {
      final Map<String, dynamic> json = const LeaderboardMessage(
        entries: <EntradaClasificacion>[
          EntradaClasificacion(alias: 'ROM', puntuacion: 12),
        ],
      ).toJson();

      expect(json[CampoMensaje.type], TipoMensajeRemoto.leaderboard);
      final LeaderboardMessage message = LeaderboardMessage.fromJson(json);
      expect(message.entries.single.alias, 'ROM');
      expect(message.entries.single.puntuacion, 12);
    });
  });
}
