// Contenido visual de mensajes del tablero. Combina texto y, si procede, una
// imagen de apoyo para dialogos informativos.

import 'package:flutter/material.dart';

import '../for_theme.dart';

/// Contenido reutilizable para mensajes mostrados sobre el tablero.
class MensajeTableroContent extends StatelessWidget {
  const MensajeTableroContent({
    required this.mensaje,
    required this.mensajeConGif,
    required this.gifAsset,
    super.key,
  });

  final String mensaje;
  final String mensajeConGif;
  final String gifAsset;

  @override
  Widget build(BuildContext context) {
    if (mensaje != mensajeConGif) {
      return Align(
        alignment: Alignment.center,
        child: Text(mensaje, textAlign: TextAlign.center),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        _GifMensaje(gifAsset: gifAsset),
        const SizedBox(width: ForSpacing.messageGap),
        Flexible(child: Text(mensaje, textAlign: TextAlign.center)),
        const SizedBox(width: ForSpacing.messageGap),
        _GifMensaje(gifAsset: gifAsset),
      ],
    );
  }
}

/// Imagen animada usada dentro de algunos mensajes del tablero.
class _GifMensaje extends StatelessWidget {
  const _GifMensaje({required this.gifAsset});

  final String gifAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ForSizes.messageGifSize,
      height: ForSizes.messageGifSize,
      child: Image.asset(gifAsset, fit: BoxFit.contain),
    );
  }
}
