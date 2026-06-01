import 'dart:io';

import 'package:for_server/config/env_file.dart';
import 'package:test/test.dart';

void main() {
  group('loadServerEnvFile', () {
    test('lee claves simples desde un archivo .env', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'for_env_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final File envFile = File('${tempDir.path}/.env');
      await envFile.writeAsString('''
# comentario
FOR_HOST=127.0.0.1
FOR_PORT=8080
FOR_DB=postgres://practicas@localhost:5432/foundations_rome
FOR_ACCESS_TOKEN=
''');

      final Map<String, String> values = await loadServerEnvFile(
        envFile: envFile,
      );

      expect(values['FOR_HOST'], '127.0.0.1');
      expect(values['FOR_PORT'], '8080');
      expect(
        values['FOR_DB'],
        'postgres://practicas@localhost:5432/foundations_rome',
      );
      expect(values['FOR_ACCESS_TOKEN'], '');
    });

    test('acepta export y valores entre comillas', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'for_env_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final File envFile = File('${tempDir.path}/.env');
      await envFile.writeAsString('''
export FOR_HOST="0.0.0.0"
FOR_ACCESS_TOKEN='token-local'
''');

      final Map<String, String> values = await loadServerEnvFile(
        envFile: envFile,
      );

      expect(values['FOR_HOST'], '0.0.0.0');
      expect(values['FOR_ACCESS_TOKEN'], 'token-local');
    });
  });
}
