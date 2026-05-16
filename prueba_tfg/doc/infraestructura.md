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
AudioService.instance.playBackgroundMusic();
AudioService.instance.stopBackgroundMusic();
```

## Apertura de enlaces

La apertura de enlaces externos con `url_launcher` se hace directamente en la UI (`presentation/screens/pantalla_menu_principal.dart`) para evitar un wrapper de un solo uso.

## Startup

Ruta: `application_config.dart`

Responsabilidades:

- `WidgetsFlutterBinding.ensureInitialized()`.
- registro de WebView/InAppWebView en Windows.
- configuracion de ventana desktop.
- arranque inicial del audio.

`main.dart` (y `bin/main.dart`) deben llamar a `ApplicationConfig.inicializar()` antes de `runApp`.

## Persistencia de partida

Ruta: `infrastructure/persistence/`

Archivos:

- `persistencia_partida.dart`: export condicional.
- `persistencia_partida_web.dart`: implementacion web.
- `persistencia_partida_stub.dart`: fallback no web.

La persistencia trabaja con strings JSON generados por `Game`.

Estado actual:

- Web: implementado con APIs de navegador.
- No web: no implementado; lanza `UnsupportedError`.

## Ranking global (SQLite y PostgreSQL)

Rutas:

- `bin/headless/ranking_global_store.dart`
- `bin/headless/ranking_global_sqlite.dart`
- `bin/headless/ranking_global_postgres.dart`
- `bin/headless/ranking_global_factory.dart`

Responsabilidades:

- definir contrato comun de persistencia.
- crear esquema si no existe en cada backend.
- registrar puntuacion maxima por alias.
- cargar top 10.
- cerrar conexion.

El servidor headless selecciona backend con `--db`:

- ruta de archivo: SQLite.
- URL `postgres://` o `postgresql://`: PostgreSQL.

El ranking vive junto al servidor headless, no como almacenamiento local del cliente Flutter.

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
- Si un adaptador necesita datos de dominio, importa tipos concretos de `domain/`.
- Evita meter widgets Flutter en `infrastructure/`, salvo inicializacion de plataforma donde Flutter sea inevitable.
