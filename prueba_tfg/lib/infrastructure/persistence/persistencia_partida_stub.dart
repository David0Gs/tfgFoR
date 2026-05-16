import 'dart:io';

Future<File> _archivoPartidaLocal({
  String fileName = 'partida_guardada.json',
}) async {
  final String? home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  final Directory baseDir = home == null || home.trim().isEmpty
      ? Directory.current
      : Directory(
          '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}Foundations of Rome',
        );

  if (!await baseDir.exists()) {
    await baseDir.create(recursive: true);
  }

  return File('${baseDir.path}${Platform.pathSeparator}$fileName');
}

Future<void> descargarPartidaJson(
  String jsonContent, {
  String fileName = 'partida_guardada.json',
}) async {
  final File archivo = await _archivoPartidaLocal(fileName: fileName);
  await archivo.writeAsString(jsonContent, flush: true);
}

Future<String?> seleccionarPartidaJson() async {
  final File archivo = await _archivoPartidaLocal();
  if (!await archivo.exists()) {
    return null;
  }

  final String contenido = await archivo.readAsString();
  return contenido.trim().isEmpty ? null : contenido;
}
