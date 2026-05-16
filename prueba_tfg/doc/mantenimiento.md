# Guia de mantenimiento

Esta guia resume donde tocar segun el tipo de cambio.

## Cambiar reglas de juego

Empieza por:

```text
lib/domain/foundations_of_rome/game/game.dart
lib/domain/foundations_of_rome/catalog/building_catalog.dart
```

Despues revisa:

- tests de `test/build_validation_test.dart`.
- bots si la regla afecta decisiones automaticas.
- servidor remoto si cambia payload o serializacion.

## Anadir edificio o monumento

1. Anadir plantilla en `building_catalog.dart`.
2. Si es monumento, anadir id a `monumentIds`.
3. Implementar requisitos en `Game._validateMonumentRequirements`.
4. Implementar beneficios inmediatos/puntuacion/ingresos si aplica.
5. Revisar modelos GLB y visor 3D si necesita asset nuevo.

## Cambiar una pantalla

```text
lib/presentation/screens/
lib/presentation/widgets/
```

Mantener reglas fuera de la UI. Si la pantalla necesita saber si una accion es valida, preferir consultar `Game.validateBuild` o estado de dominio.

## Cambiar bots

```text
lib/application/bots/
```

Clases importantes:

- `FoundationsOfRomeBotService`
- `BotPlannedAction`
- `LocalBotTurnRunner`

## Cambiar modo remoto

```text
lib/infrastructure/online/sesion_remota.dart
bin/for_headless_server.dart
```

Actualizar tambien:

- `doc/modo_remoto.md`
- tests relacionados
- cualquier payload de UI en `PantallaTablero`

## Cambiar ranking

```text
lib/domain/entrada_leaderboard.dart
bin/headless/ranking_global_sqlite.dart
```

## Cambiar guardado/carga

```text
lib/infrastructure/persistence/
lib/domain/foundations_of_rome/game/game.dart
```

Si cambia el JSON del juego, actualizar `toJson`, `fromJson` y tests.

## Cambiar audio

```text
lib/infrastructure/audio/
```

Mantener la fachada `AudioService` estable para no obligar a tocar UI.

## Cambiar visor 3D

```text
lib/visor_3d/
lib/juego/controladores/controlador_tablero.dart
```

Si se anade un comando nuevo desde Flutter:

1. Anadirlo en `I3DViewerController`.
2. Implementarlo en web.
3. Implementarlo en desktop.
4. Usarlo desde `TableroController` o UI.

## Comandos de validacion

```bash
dart format lib test bin
dart analyze
flutter test
```

## Avisos conocidos del analizador

Actualmente quedan avisos informativos no bloqueantes:

- `avoid_print` en CLI, motor y trazas de visor.
- nombre historico `f_o_r.dart`.
- uso de `dart:html` en implementaciones web.
- nombres de enum `Era.I`, `Era.II`, `Era.III`.

No son errores funcionales. Si se limpian, hacerlo en cambios pequenos y con tests.

## Regla para nuevas carpetas

Usar nombres por responsabilidad:

- `domain`: reglas y modelos puros.
- `application`: coordinacion/casos de uso.
- `presentation`: Flutter UI.
- `infrastructure`: adaptadores externos.
- `visor_3d`: render 3D.

Evitar nombres genericos como `app`, `utils` o `misc` salvo que haya una razon muy concreta.
