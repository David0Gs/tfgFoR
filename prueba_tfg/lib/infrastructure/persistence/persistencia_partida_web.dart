// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Future<void> descargarPartidaJson(
  String jsonContent, {
  String fileName = 'partida_guardada.json',
}) async {
  final html.Blob blob = html.Blob(<Object>[
    utf8.encode(jsonContent),
  ], 'application/json');
  final String url = html.Url.createObjectUrlFromBlob(blob);
  final html.AnchorElement anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<String?> seleccionarPartidaJson() async {
  final Completer<String?> completer = Completer<String?>();
  final html.FileUploadInputElement input = html.FileUploadInputElement()
    ..accept = '.json,application/json';

  input.onChange.listen((_) {
    final html.File? file = input.files?.isNotEmpty == true
        ? input.files!.first
        : null;
    if (file == null) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return;
    }

    final html.FileReader reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(reader.result as String?);
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(reader.error ?? 'Error leyendo el archivo.');
      }
    });
    reader.readAsText(file);
  });

  input.click();
  return completer.future;
}
