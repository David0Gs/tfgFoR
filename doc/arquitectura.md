# Arquitectura

La aplicacion sigue una arquitectura por capas. La regla practica es que las capas internas no deben depender de las externas:

```text
frontend      -> packages
server          -> packages
presentation    -> application -> for_core
infrastructure  -> application/for_core cuando necesita tipos compartidos
visor_3d        -> presentation/controlador_tablero mediante interfaces de controlador
```

## Capas

### `packages`

Contiene las reglas y entidades que describen el juego y datos puros de negocio.
No depende de Flutter ni de infraestructura externa. Es el paquete compartido
entre la app Flutter y el servidor Dart independiente.

Subcarpetas relevantes:

- `packages/lib/core/foundations_of_rome/`: motor principal de Foundations of Rome.
- `packages/lib/core/entrada_leaderboard.dart`: DTO del ranking.
- `packages/lib/core/alias_online.dart`: validacion de alias remoto.

### `application/`

Contiene coordinacion de casos de uso y logica que no es UI ni infraestructura.
Puede usar `for_core`, pero no deberia conocer detalles de Flutter salvo cuando
una clase heredada ya lo requiera.

Subcarpetas:

- `application/bots/`: decision de bots y ejecucion de turnos locales.
- `application/local_game/`: configuracion de partidas locales.

### `presentation/`

Contiene widgets y pantallas Flutter. Su responsabilidad es presentar estado, capturar intenciones del usuario y delegar en `Juego`, controladores o servicios.

Subcarpetas:

- `presentation/screens/`: pantallas completas.
- `presentation/widgets/`: widgets reutilizables.

### `infrastructure/`

Contiene adaptadores hacia recursos externos: audio, WebSocket y almacenamiento del navegador.

Subcarpetas:

- `audio/`: fachada y backend web/native.
- `persistence/`: descarga/carga JSON de partidas.

Archivo relevante:

- `sesion_remota.dart`: cliente WebSocket usado por Flutter.

Nota: la persistencia del ranking global no vive en `lib/infrastructure/`; esta
en el paquete `backend`, porque pertenece al backend independiente.

### `visor_3d/`

Subsistema de renderizado Three.js embebido. Expone widgets/controladores para Flutter, pero internamente separa implementacion web y desktop.

### CLI y servidor

- `bin/for_cli.dart` reutiliza la logica de `lib/for_cli_app.dart`.
- `backend/bin/start_server.dart` levanta el servidor remoto.
- `backend/lib/` contiene HTTP, WebSocket, salas y persistencia.

### Controlador del tablero

`lib/controlador_tablero.dart` conecta la UI con el visor 3D. No vive dentro de una carpeta `juego/`; esa ruta es historica y ya no existe.

## Dependencias principales entre capas

```text
lib/main.dart
  -> lib/app_entrypoint.dart
  -> ApplicationConfig
  -> infrastructure/audio
  -> infrastructure/persistence
  -> infrastructure/sesion_remota
  -> presentation/screens
  -> application/local_game
  -> for_core/core/foundations_of_rome

presentation/screens/pantalla_tablero.dart
  -> Juego
  -> LocalBotTurnRunner
  -> SesionRemotaController
  -> AudioService
  -> Visor3D
  -> TableroController

backend/bin/start_server.dart
  -> FoundationsServer
  -> for_core/Juego
  -> RankingRepository
  -> PartidaRepository
```

## Reglas de mantenimiento

- Si cambias una regla de juego, empieza en `packages/lib/core/foundations_of_rome/game.dart`.
- Si cambias una pantalla, empieza en `presentation/screens/`.
- Si cambias un widget reutilizable, empieza en `presentation/widgets/`.
- Si cambias WebSocket, audio o almacenamiento de partidas, empieza en `infrastructure/`.
- Si cambias el ranking SQLite/PostgreSQL del servidor, empieza en `backend/lib/persistence/`.
- Si cambias el render 3D, empieza en `visor_3d/`.
- Evita volver a crear carpetas genericas como `app/`; usa nombres de capa o responsabilidad.
