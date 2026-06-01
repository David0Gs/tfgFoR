# Guia de mantenimiento

Esta guia resume donde tocar segun el tipo de cambio.

## Cambiar reglas de juego

Empieza por:

```text
packages/lib/core/foundations_of_rome/game.dart
packages/lib/core/foundations_of_rome/building_catalog.dart
```

Despues revisa:

- tests de `test/build_validation_test.dart`.
- bots si la regla afecta decisiones automaticas.
- servidor remoto si cambia payload o serializacion.

## Anadir edificio o monumento

1. Anadir plantilla en `building_catalog.dart`.
2. Si es monumento, anadir id a `idsMonumentos`.
3. Implementar requisitos en `Juego._validateMonumentRequirements`.
4. Implementar beneficios inmediatos/puntuacion/ingresos si aplica.
5. Revisar modelos GLB y visor 3D si necesita asset nuevo.

## Cambiar una pantalla

```text
lib/presentation/screens/
lib/presentation/widgets/
```

Mantener reglas fuera de la UI. Si la pantalla necesita saber si una accion es valida, preferir consultar `Juego.validarConstruccion`, `Juego.puedeColocarEdificio` o estado de dominio.

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
lib/infrastructure/sesion_remota.dart
backend/bin/start_server.dart
backend/lib/
```

Actualizar tambien:

- `doc/modo_remoto.md`
- tests relacionados
- cualquier payload de UI en `PantallaTablero`

## Cambiar ranking

```text
packages/lib/core/entrada_leaderboard.dart
backend/lib/persistence/ranking_repository.dart
backend/lib/persistence/sqlite_ranking_repository.dart
backend/lib/persistence/postgres_ranking_repository.dart
```

## Cambiar guardado/carga local

```text
lib/infrastructure/persistence/
packages/lib/core/foundations_of_rome/game.dart
```

Si cambia el JSON del juego, actualizar `toJson`, `fromJson` y tests.

## Cambiar persistencia remota de partidas

```text
backend/lib/persistence/partida_repository.dart
backend/lib/persistence/sqlite_partida_repository.dart
backend/lib/persistence/postgres_partida_repository.dart
backend/test/partida_repository_sqlite_test.dart
```

## Cambiar audio

```text
lib/infrastructure/audio/
```

Mantener la fachada `AudioService` estable para no obligar a tocar UI.

## Cambiar visor 3D

```text
lib/visor_3d/
lib/controlador_tablero.dart
```

Si se anade un comando nuevo desde Flutter:

1. Anadirlo en `I3DViewerController`.
2. Implementarlo en web.
3. Implementarlo en desktop.
4. Implementarlo o degradarlo en mobile si aplica.
5. Usarlo desde `TableroController` o UI.

## Comandos de validacion

```bash
dart format lib test bin
flutter analyze
flutter test
```

## Avisos conocidos del analizador

Tras la ultima revision, `flutter analyze` no muestra issues. Si aparecen avisos nuevos, resolverlos en cambios pequenos y con tests.

## Regla para nuevas carpetas

Usar nombres por responsabilidad:

- `domain`: reglas y modelos puros.
- `application`: coordinacion/casos de uso.
- `presentation`: Flutter UI.
- `infrastructure`: adaptadores externos.
- `visor_3d`: render 3D.

Evitar nombres genericos como `app`, `utils` o `misc` salvo que haya una razon muy concreta.
