// Dialogo de entrada al modo remoto. Recoge la URL del servidor, el alias de
// sala y el alias del jugador antes de que app_entrypoint.dart cree la sesion
// WebSocket con el backend.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:for_core/core.dart';
import '../../infrastructure/sesion_remota.dart';
import '../for_theme.dart';

/// Widget de formulario para crear una sala remota nueva o unirse a una.
///
/// Devuelve los datos como Map para que el flujo de arranque remoto pueda
/// decidir como abrir la conexion.
class RemoteJoinDialog extends StatefulWidget {
  const RemoteJoinDialog({
    required this.initialUrl,
    required this.initialAlias,
    super.key,
  });

  final String initialUrl;
  final String initialAlias;

  @override
  State<RemoteJoinDialog> createState() => _RemoteJoinDialogState();
}

/// Estado interno del dialogo.
///
/// Mantiene los controladores de texto y los errores de validacion mientras el
/// usuario cambia entre crear sala o unirse.
class _RemoteJoinDialogState extends State<RemoteJoinDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _aliasController;
  late final TextEditingController _roomAliasController;
  bool _crearSala = false;
  int _numeroJugadores = 2;
  String? _aliasError;
  String? _roomAliasError;

  /// Inicializa los controladores con datos sugeridos o valores por defecto.
  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _aliasController = TextEditingController(text: widget.initialAlias);
    _roomAliasController = TextEditingController();
  }

  /// Libera los controladores creados por el dialogo al cerrar el modal.
  @override
  void dispose() {
    _urlController.dispose();
    _aliasController.dispose();
    _roomAliasController.dispose();
    super.dispose();
  }

  /// Valida alias de jugador y sala antes de cerrar el dialogo.
  void _confirmarUnion() {
    final String alias = AliasOnline.normalizar(_aliasController.text);
    final String? error = AliasOnline.mensajeError(alias);
    if (error != null) {
      setState(() {
        _aliasError = error;
      });
      return;
    }
    final String roomAlias = _roomAliasController.text.trim().toUpperCase();
    final String? roomAliasError = _validarAliasSala(roomAlias);
    if (roomAliasError != null) {
      setState(() {
        _roomAliasError = roomAliasError;
      });
      return;
    }

    Navigator.of(context, rootNavigator: true).pop(<String, String>{
      'url': _urlController.text.trim(),
      'alias': alias,
      'roomAlias': roomAlias,
      'createRoom': _crearSala.toString(),
      'players': _numeroJugadores.toString(),
    });
  }

  /// Valida el alias legible que identifica una sala remota.
  String? _validarAliasSala(String alias) {
    if (alias.length < 3 || alias.length > 20) {
      return 'Entre 3 y 20 caracteres.';
    }
    if (!RegExp(r'^[A-Z0-9_-]+$').hasMatch(alias)) {
      return 'Solo letras, numeros, guion y guion bajo.';
    }
    return null;
  }

  /// Construye el formulario visual para crear o unirse a una sala remota.
  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double dialogWidth = (screenSize.width - 48)
        .clamp(320.0, ForSizes.remoteJoinDialogWidth)
        .toDouble();
    final double maxContentHeight = (MediaQuery.sizeOf(context).height - 170)
        .clamp(140.0, 380.0)
        .toDouble();
    return PointerInterceptor(
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
        title: Text(_crearSala ? 'Crear sala remota' : 'Unirse a sala remota'),
        content: SizedBox(
          width: dialogWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxContentHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<bool>(
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(value: false, label: Text('Unirse')),
                      ButtonSegment<bool>(value: true, label: Text('Crear')),
                    ],
                    selected: <bool>{_crearSala},
                    onSelectionChanged: (Set<bool> selected) {
                      setState(() {
                        // Al alternar entre unirse y crear se muestran u ocultan
                        // los campos propios de la creacion de sala.
                        _crearSala = selected.first;
                      });
                    },
                  ),
                  const SizedBox(height: ForSpacing.sm),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'URL del servidor',
                      hintText:
                          SesionRemotaController.urlServidorLocalPorDefecto,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: ForSpacing.sm),
                  TextField(
                    controller: _roomAliasController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Alias de sala',
                      hintText: 'ROMA',
                      helperText: _crearSala
                          ? 'Se reserva mientras quede algun jugador conectado.'
                          : 'Nombre de la sala creada por el primer jugador.',
                      errorText: _roomAliasError,
                    ),
                    onChanged: (_) {
                      if (_roomAliasError == null) {
                        return;
                      }
                      // Al editar de nuevo se limpia el error para no mantener un
                      // aviso antiguo mientras el usuario corrige el texto.
                      setState(() {
                        _roomAliasError = null;
                      });
                    },
                    onSubmitted: (_) => _confirmarUnion(),
                  ),
                  if (_crearSala) ...[
                    const SizedBox(height: ForSpacing.sm),
                    DropdownButtonFormField<int>(
                      initialValue: _numeroJugadores,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Numero de jugadores',
                      ),
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem<int>(value: 2, child: Text('2')),
                        DropdownMenuItem<int>(value: 3, child: Text('3')),
                        DropdownMenuItem<int>(value: 4, child: Text('4')),
                        DropdownMenuItem<int>(value: 5, child: Text('5')),
                      ],
                      onChanged: (int? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _numeroJugadores = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: ForSpacing.sm),
                  TextField(
                    controller: _aliasController,
                    maxLength: AliasOnline.longitud,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Alias online',
                      hintText: 'ABC',
                      helperText:
                          '3 caracteres exactos. Se muestran en ranking y resumen final.',
                      errorText: _aliasError,
                    ),
                    onChanged: (_) {
                      if (_aliasError == null) {
                        return;
                      }
                      // Mismo comportamiento para el alias del jugador: el error
                      // desaparece en cuanto el usuario intenta corregirlo.
                      setState(() {
                        _aliasError = null;
                      });
                    },
                    onSubmitted: (_) => _confirmarUnion(),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _confirmarUnion,
            child: Text(_crearSala ? 'Crear' : 'Unirse'),
          ),
        ],
      ),
    );
  }
}
