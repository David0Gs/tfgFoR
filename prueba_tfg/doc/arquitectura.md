# Arquitectura

La aplicacion sigue una arquitectura por capas. La regla practica es que las capas internas no deben depender de las externas:

```text
presentation  -> application -> domain
infrastructure -> application/domain cuando necesita tipos compartidos
visor_3d      -> presentation/juego mediante interfaces de controlador
```

## Capas

### `domain/`

Contiene las reglas y entidades que describen el juego y datos puros de negocio. No debe depender de Flutter ni de infraestructura externa.

Subcarpetas relevantes:

- `domain/foundations_of_rome/`: motor principal de Foundations of Rome.
- `domain/entrada_leaderboard.dart`: DTO del ranking.
- `domain/alias_online.dart`: validacion de alias remoto.

### `application/`

Contiene coordinacion de casos de uso y logica que no es UI ni infraestructura. Puede usar `domain/`, pero no deberia conocer detalles de Flutter salvo cuando una clase heredada ya lo requiera.

Subcarpetas:

- `application/bots/`: decision de bots y ejecucion de turnos locales.
- `application/local_game/`: configuracion de partidas locales.
### `presentation/`

Contiene widgets y pantallas Flutter. Su responsabilidad es presentar estado, capturar intenciones del usuario y delegar en `Game`, controladores o servicios.

Subcarpetas:

- `presentation/screens/`: pantallas completas.
- `presentation/widgets/`: widgets reutilizables.

### `infrastructure/`

Contiene adaptadores hacia recursos externos: audio, navegador, SQLite, WebSocket, plataforma y almacenamiento del navegador.

Subcarpetas:

- `audio/`: fachada y backend web/native.
- `browser/`: apertura de enlaces.
- `leaderboard/`: persistencia SQLite.
- `online/`: cliente remoto WebSocket.
- `persistence/`: descarga/carga JSON de partidas.
- `startup/`: bootstrap de plataforma.

### `visor_3d/`

Subsistema de renderizado Three.js embebido. Expone widgets/controladores para Flutter, pero internamente separa implementacion web y desktop.

### `FoR/`

Capa heredada en retirada:

- Los imports del motor deben apuntar directamente a `domain/foundations_of_rome/foundations_of_rome.dart`.
- El CLI de Foundations of Rome ahora entra por `bin/for_cli.dart` y reutiliza logica en `lib/for_cli_app.dart`.

### `juego/`

Capa puente heredada. Actualmente conserva `controlador_tablero.dart`, que conecta la UI con el visor 3D. Los modelos genericos de piezas (`TipoPieza`, `PiezaJuego`, `Modelo3D`, etc.) fueron eliminados porque no formaban parte del flujo real de Foundations of Rome.

## Dependencias principales entre capas

```text
bin/main.dart
  -> lib/app_entrypoint.dart
  -> infrastructure/configuracion_app
  -> infrastructure/audio
  -> infrastructure/persistence
  -> infrastructure/sesion_remota
  -> presentation/screens
  -> application/local_game
  -> domain/foundations_of_rome

presentation/screens/pantalla_tablero.dart
  -> Game
  -> LocalBotTurnRunner
  -> SesionRemotaController
  -> AudioService
  -> Visor3D
  -> TableroController

bin/for_headless_server.dart
  -> Game
  -> AliasOnline
  -> RankingGlobalSqlite
```

## Reglas de mantenimiento

- Si cambias una regla de juego, empieza en `domain/foundations_of_rome/game/game.dart`.
- Si cambias una pantalla, empieza en `presentation/screens/`.
- Si cambias un widget reutilizable, empieza en `presentation/widgets/`.
- Si cambias WebSocket, SQLite, audio o almacenamiento, empieza en `infrastructure/`.
- Si cambias el render 3D, empieza en `visor_3d/`.
- Evita volver a crear carpetas genericas como `app/`; usa nombres de capa o responsabilidad.
