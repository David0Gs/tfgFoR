// Persistencia de partidas para plataformas no web. En movil usa el directorio
// interno de documentos de la app; en escritorio usa Documents del usuario.

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Devuelve el archivo local usado para guardar o cargar una partida.
Future<File> _archivoPartidaLocal({
  String fileName = 'partida_guardada.json',
}) async {
  final Directory baseDir = await _directorioPartidas();

  if (!await baseDir.exists()) {
    await baseDir.create(recursive: true);
  }

  return File('${baseDir.path}${Platform.pathSeparator}$fileName');
}

Future<Directory> _directorioPartidas() async {
  if (Platform.isAndroid || Platform.isIOS) {
    final Directory appDocuments = await getApplicationDocumentsDirectory();
    return Directory(
      '${appDocuments.path}${Platform.pathSeparator}Foundations of Rome',
    );
  }

  final String? home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null && home.trim().isNotEmpty) {
    return Directory(
      '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}Foundations of Rome',
    );
  }

  return Directory(
    '${Directory.current.path}${Platform.pathSeparator}Foundations of Rome',
  );
}

/// Guarda el JSON de una partida en el disco local.
Future<void> descargarPartidaJson(
  String jsonContent, {
  String fileName = 'partida_guardada.json',
}) async {
  final File archivo = await _archivoPartidaLocal(fileName: fileName);
  await archivo.writeAsString(jsonContent, flush: true);
}

/// Carga el JSON de una partida guardada en el disco local.
Future<String?> seleccionarPartidaJson() async {
  final File archivo = await _archivoPartidaLocal();
  if (!await archivo.exists()) {
    return null;
  }

  final String contenido = await archivo.readAsString();
  return contenido.trim().isEmpty ? null : contenido;
}
