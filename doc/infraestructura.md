# Infraestructura

La capa `lib/infrastructure/` contiene adaptadores hacia recursos externos. Su objetivo es aislar detalles de plataforma para que presentation/application/domain no tengan que conocerlos.

## Audio

Ruta: `infrastructure/audio/`

Archivos:

- `audio_service.dart`: fachada publica.
- `audio_service_contract.dart`: contrato comun.
- `audio_service_native.dart`: implementacion con `audioplayers`.
- `audio_service_web.dart`: implementacion con `AudioElement`.

El import condicional en `audio_service.dart` selecciona backend web o nativo.

Uso tipico:

```dart
await AudioService.instance.initialize();
await AudioService.instance.ensureStarted();
await AudioService.instance.toggleMuted();
AudioService.instance.registrarInteraccionUsuario();
```

## Apertura de enlaces

La apertura de enlaces externos con `url_launcher` se hace directamente en la UI (`presentation/screens/pantalla_menu_principal.dart`) para evitar un wrapper de un solo uso.

## Startup

Ruta: `application_config.dart`

Responsabilidades:

- `WidgetsFlutterBinding.ensureInitialized()`.
- registro de WebView/InAppWebView en Windows.
- configuracion de ventana desktop.
- registro de interacciones globales para permitir audio tras gesto de usuario.

`lib/app_entrypoint.dart` llama a `ApplicationConfig.inicializar()` antes de `runApp`. Despues del primer frame inicializa `AudioService`.

## Persistencia de partida

Ruta: `infrastructure/persistence/`

Archivos:

- `persistencia_partida.dart`: export condicional.
- `persistencia_partida_web.dart`: implementacion web.
- `persistencia_partida_stub.dart`: implementacion no web basada en archivo local.

La persistencia trabaja con strings JSON generados por `Juego`.

Estado actual:

- Web: implementado con APIs de navegador.
- No web: guarda y carga `partida_guardada.json` en una carpeta `Foundations of Rome` dentro de Documents del usuario; si no encuentra partida, devuelve `null`.

## Sesiones remotas recordadas

Ruta: `infrastructure/`

Archivos:

- `remote_session_store.dart`: export condicional.
- `remote_session_store_web.dart`: implementacion web basada en `localStorage`.
- `remote_session_store_stub.dart`: implementacion no web basada en archivo JSON local.

Responsabilidades:

- guardar un `clientId` estable por navegador, instalacion o dispositivo.
- recordar `sessionToken` por combinacion de servidor/sala/alias de jugador.
- eliminar tokens caducados cuando el servidor los rechaza.

Esta persistencia no guarda la partida completa. Solo ayuda a reconectar a una
plaza remota mientras la sala sigue viva en el servidor.

## Ranking global (SQLite y PostgreSQL)

Rutas:

- `backend/lib/config/env_file.dart`
- `backend/lib/config/server_config.dart`
- `backend/lib/logging/server_logger.dart`
- `backend/lib/persistence/ranking_repository.dart`
- `backend/lib/persistence/sqlite_ranking_repository.dart`
- `backend/lib/persistence/postgres_ranking_repository.dart`
- `backend/lib/persistence/ranking_repository_factory.dart`
- `backend/lib/persistence/sqlite_backup_sync.dart`

Responsabilidades:

- cargar `.env` y combinarlo con argumentos de consola.
- validar la configuracion de arranque del servidor.
- emitir logs con nivel y timestamp.
- definir contrato comun de persistencia de ranking.
- crear esquema si no existe en cada backend.
- registrar puntuacion maxima por alias.
- cargar top 10.
- cerrar conexion.
- sincronizar SQLite y PostgreSQL cuando se configura respaldo local.

El servidor Dart selecciona backend con `--db` o `FOR_DB`:

- ruta de archivo: SQLite.
- URL `postgres://` o `postgresql://`: PostgreSQL.

El ranking vive en el paquete `backend`, no como almacenamiento local del cliente Flutter.

Tabla usada:

```text
leaderboard
  alias       Alias online de 3 caracteres. Clave primaria.
  score       Mejor puntuacion guardada para ese alias.
  updated_at  Fecha de ultima actualizacion.
```

## Persistencia remota de partidas

Rutas:

- `backend/lib/persistence/partida_repository.dart`
- `backend/lib/persistence/sqlite_partida_repository.dart`
- `backend/lib/persistence/postgres_partida_repository.dart`
- `backend/lib/persistence/partida_repository_factory.dart`

Responsabilidades:

- registrar partidas creadas.
- guardar el ultimo snapshot JSON de cada partida.
- registrar eventos de acciones y conexion.
- cerrar conexion.

Tablas usadas:

```text
games
  game_id       Identificador de partida, por ejemplo game_0001.
  player_count  Numero de jugadores.
  status        Estado general de la partida.
  created_at    Fecha de creacion.
  updated_at    Fecha de ultima actualizacion.

game_snapshots
  game_id        Identificador de partida. Clave primaria.
  snapshot_json  Estado completo de Juego serializado como JSON.
  updated_at     Fecha de ultima escritura del snapshot.

game_events
  id            Identificador autoincremental del evento.
  game_id       Partida asociada.
  player_id     Jugador que provoco el evento, si aplica.
  type          Tipo de evento o accion.
  payload_json  Datos del evento serializados como JSON.
  created_at    Fecha de registro.

schema_migrations
  version     Version aplicada.
  name        Nombre descriptivo de la migracion.
  applied_at  Fecha de aplicacion.
```

El servidor conserva `game_snapshots` como auditoria y base para futuras
herramientas de recuperacion, pero no reactiva salas antiguas automaticamente al
arrancar. Las sesiones WebSocket y `sessionToken` siguen siendo memoria de
proceso. Si una sala se queda vacia, se elimina de memoria; si no queda ninguna
sala, `game_0001` puede reutilizarse como sala limpia. Un `sessionToken` antiguo
solo permite recuperar la plaza en la misma sala viva; no sirve para entrar en
otra sala ni para generar una nueva.

Las salas activas pueden tener un alias humano, por ejemplo `ROMA`. El alias se
guarda en memoria junto a la sala, debe ser unico mientras la sala este activa y
se libera cuando la sala se elimina. El cliente puede entrar por
`/rooms/ROMA/ws` en lugar de compartir la ruta tecnica `/games/game_0001/ws`.

## Online

Ruta: `infrastructure/sesion_remota.dart`

`SesionRemotaController` encapsula el cliente WebSocket usado por Flutter.

Responsabilidades:

- conectar/desconectar.
- enviar `join`, acciones y solicitud de ranking.
- procesar snapshots.
- exponer presencia, errores y estado remoto a la UI.

## Pautas

- Si algo habla con sistema operativo, navegador, red, SQLite o paquetes externos, probablemente va en `infrastructure/`.
- Si un adaptador necesita datos de dominio, importa tipos concretos de `for_core`.
- Evita meter widgets Flutter en `infrastructure/`, salvo inicializacion de plataforma donde Flutter sea inevitable.
