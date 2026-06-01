# Estructura del monorepo

Este repositorio ya no es solo una aplicacion Flutter. Ahora esta dividido en
varias piezas para que la app, el servidor y la logica compartida puedan crecer
sin mezclarse.

## Vista general

```text
tfgFoR/
  frontend/          App Flutter que ve y usa el jugador.
  packages/            Paquete for_core: reglas, modelos y protocolo remoto.
  backend/              Backend Dart independiente.
```

## `frontend/`

Es la aplicacion Flutter. Contiene pantallas, widgets, audio, visor 3D,
persistencia local de partidas y el cliente remoto.

Archivos importantes:

```text
frontend/lib/main.dart
frontend/lib/app_entrypoint.dart
frontend/lib/controlador_tablero.dart
frontend/lib/infrastructure/sesion_remota.dart
frontend/lib/presentation/
frontend/lib/visor_3d/
```

La app depende de `for_core` para usar las reglas del juego y el contrato
remoto compartido:

```yaml
for_core:
  path: ../packages
```

No debe depender de `backend`. Si una pantalla necesita jugar online, debe
hacerlo a traves de `SesionRemotaController`, no importando clases internas del
backend.

Comandos habituales:

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter run
```

Compilaciones de despliegue:

```bash
cd frontend
flutter build windows --release
flutter build apk --release --split-per-abi
flutter build web --release
```

La guia completa de despliegue esta en `doc/despliegue.md`.

## `packages/`

Es el paquete compartido. Aqui vive la parte que debe ser igual para cliente y
servidor: entidades, reglas, validaciones, objetos comunes y contrato remoto.

Archivos importantes:

```text
packages/lib/core.dart
packages/lib/protocol.dart
packages/lib/for_core.dart
packages/lib/for_protocol.dart
packages/lib/core/
packages/lib/protocol/
packages/lib/core/foundations_of_rome/
packages/lib/core/alias_online.dart
packages/lib/core/entrada_leaderboard.dart
```

La separacion interna es:

- `core.dart` exporta `lib/core/`: reglas, entidades y modelos del juego.
- `protocol.dart` exporta `lib/protocol/`: mensajes y campos JSON del modo remoto.
- `for_core.dart` y `for_protocol.dart` son entradas publicas comodas para
  importar nucleo o protocolo por separado.

En `protocol.dart` viven tipos como:

```text
JoinRequest
JoinedMessage
ActionRequest
ActionAcceptedMessage
ActionRejectedMessage
SnapshotMessage
LeaderboardMessage
```

Este paquete no debe importar Flutter ni codigo del servidor. Debe mantenerse
como Dart puro para poder usarse desde cualquier lado.

Comandos habituales:

```bash
cd packages
dart pub get
dart analyze
dart test
```

## `backend/`

Es el backend Dart. Se puede ejecutar en otra maquina sin arrancar la app
Flutter. Se encarga de:

- crear y gestionar partidas remotas;
- aceptar conexiones WebSocket;
- exponer endpoints HTTP;
- guardar ranking;
- guardar snapshots y eventos de partida;
- usar SQLite o PostgreSQL.

Archivos importantes:

```text
backend/bin/start_server.dart
backend/lib/foundations_server.dart
backend/lib/rooms/
backend/lib/persistence/
```

El servidor depende de `for_core` para ejecutar las mismas reglas que la app y
usar el mismo protocolo remoto:

```yaml
for_core:
  path: ../packages
```

Comandos habituales:

```bash
cd backend
dart pub get
dart analyze
dart test
dart run bin/start_server.dart
```

El servidor carga automaticamente `backend/.env`. Tambien acepta variables de
entorno o argumentos de consola:

```bash
cd backend
FOR_DB=leaderboard.sqlite3 FOR_PORT=8080 dart run bin/start_server.dart
```

Para arrancarlo desde casa de forma comoda:

```bash
cd backend
cp .env.example .env
dart run bin/start_server.dart
```

En macOS o Linux tambien se puede usar `sh run-server.sh`; en Windows,
`run-server.ps1`.

Ejemplo exponiendo el servidor a otros dispositivos de la red:

```bash
cd backend
dart run bin/start_server.dart --host=0.0.0.0 --port=8080 --players=3 --db=leaderboard.sqlite3
```

Para consultar partidas desde el navegador:

```text
http://127.0.0.1:8080/games
```

El flujo recomendado para jugadores es entrar por alias de sala. Por ejemplo,
si el primer jugador crea la sala `ROMA`, el WebSocket interno queda asi:

```text
ws://127.0.0.1:8080/rooms/ROMA/ws
```

La ruta tecnica `/games/game_0001/ws` sigue existiendo para compatibilidad y
tests, pero no es la forma comoda de compartir una partida.

## Regla mental

- Si cambia una regla de Foundations of Rome, normalmente va en `packages`.
- Si cambia un mensaje remoto o campo JSON de WebSocket, normalmente va en
  `packages/lib/protocol/remote_protocol.dart`.
- Si cambia algo visual o de interaccion, normalmente va en `frontend`.
- Si cambia multijugador remoto, HTTP, WebSocket o BBDD, normalmente va en `backend`.

Esta separacion permite que el juego compilado se conecte a un servidor abierto
en casa o desplegado en la nube sin llevar dentro todo el backend.
