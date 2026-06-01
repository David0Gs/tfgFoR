# Modo remoto y ranking

El modo remoto usa WebSocket entre el cliente Flutter y un servidor Dart
independiente situado en `backend/`.

## Componentes

Cliente:

```text
lib/infrastructure/sesion_remota.dart
lib/presentation/screens/pantalla_tablero.dart
lib/presentation/widgets/remote_join_dialog.dart
lib/presentation/widgets/remote_leaderboard_dialog.dart
```

Arranque del servidor:

```text
backend/bin/start_server.dart
```

Backend:

```text
backend/lib/foundations_server.dart
backend/lib/rooms/game_room.dart
backend/lib/rooms/game_room_manager.dart
backend/lib/rooms/player_session.dart
backend/lib/persistence/partida_repository.dart
backend/lib/persistence/sqlite_partida_repository.dart
backend/lib/persistence/postgres_partida_repository.dart
backend/lib/persistence/partida_repository_factory.dart
```

Paquete compartido:

```text
packages/lib/core/foundations_of_rome/
packages/lib/core/alias_online.dart
packages/lib/core/entrada_leaderboard.dart
packages/lib/protocol.dart
packages/lib/protocol/remote_protocol.dart
```

Dentro de `packages` hay un unico `pubspec.yaml`, pero la carpeta
`lib/core/` contiene las reglas y modelos del juego, mientras que
`lib/protocol/` contiene el contrato JSON usado por WebSocket y HTTP.

Ranking:

```text
backend/lib/persistence/ranking_repository.dart
backend/lib/persistence/sqlite_ranking_repository.dart
backend/lib/persistence/postgres_ranking_repository.dart
backend/lib/persistence/ranking_repository_factory.dart
```

La app Flutter no contiene la persistencia de ranking; solo consume el servidor.

## Arranque del servidor

Para despliegue completo de Windows, Android, web y backend en casa, ver tambien
`despliegue.md`.

Para probar en local con dos navegadores, el flujo recomendado es:

```bash
cd backend
cp .env.example .env
dart run bin/start_server.dart
```

En `backend/.env`, una configuracion minima para pruebas locales seria:

```env
FOR_HOST=127.0.0.1
FOR_PORT=8080
FOR_PLAYERS=2
FOR_DB=leaderboard.sqlite3
FOR_SQLITE_FALLBACK=fallback.sqlite3
FOR_ACCESS_TOKEN=
FOR_RESTORE_ROOMS=false
```

Cuando el servidor arranca correctamente muestra una linea similar a:

```text
Servidor listo en http://127.0.0.1:8080 y ws://127.0.0.1:8080.
```

Esa terminal debe quedarse abierta mientras se prueba el modo remoto.

Tambien se puede arrancar directamente con Dart:

```bash
cd backend
dart run bin/start_server.dart
```

Ese comando lee automaticamente `backend/.env`. Si el script no tiene permisos
de ejecucion en macOS o Linux, se puede lanzar igualmente con:

```bash
cd backend
sh run-server.sh
```

Argumentos habituales:

```bash
dart run bin/start_server.dart --host=0.0.0.0 --port=8080 --players=3 --db=leaderboard.sqlite3
```

Tambien se puede usar configuracion por variables de entorno:

```bash
cd backend
FOR_HOST=0.0.0.0 FOR_PORT=8080 FOR_PLAYERS=3 FOR_DB=leaderboard.sqlite3 dart run bin/start_server.dart
```

Variables disponibles:

```text
FOR_HOST             Host de escucha. Equivale a --host.
FOR_PORT             Puerto de escucha. Equivale a --port.
FOR_PLAYERS          Jugadores de la partida por defecto. Equivale a --players.
FOR_DB               BBDD principal. Equivale a --db.
FOR_SQLITE_FALLBACK  SQLite de respaldo. Equivale a --sqlite-fallback.
FOR_ACCESS_TOKEN     Token opcional para crear/unirse a partidas.
FOR_RESTORE_ROOMS    Restaura snapshots antiguos como salas al arrancar.
```

Los argumentos de consola tienen prioridad sobre las variables. Por ejemplo,
si `FOR_PORT=8080` pero se arranca con `--port=9090`, se usa `9090`.

Hay una plantilla en:

```text
backend/.env.example
```

Para uso local en casa puedes copiarla como `.env` y arrancar con:

```bash
cd backend
dart run bin/start_server.dart
```

En Windows:

```powershell
cd backend
.\run-server.ps1
```

El ejecutable Dart carga `.env` automaticamente. Los scripts solo son atajos
para hacer lo mismo.

La BBDD es obligatoria, pero puede venir de `FOR_DB` en `.env` o de `--db` por
consola. Selecciona backend por formato:

- ruta de archivo: usa SQLite.
- URL `postgres://` o `postgresql://`: usa PostgreSQL.

Ejemplo PostgreSQL:

```bash
dart run bin/start_server.dart --host=0.0.0.0 --port=8080 --players=3 --db=postgres://usuario:password@localhost:5432/for_db
```

Tambien se puede indicar un SQLite de respaldo para desarrollo o despliegues
caseros donde PostgreSQL pueda estar temporalmente caido:

```bash
dart run bin/start_server.dart --host=0.0.0.0 --port=8080 --players=3 --db=postgres://usuario:password@localhost:5432/for_db --sqlite-fallback=fallback.sqlite3
```

Ese fallback solo se usa si `--db` apunta a PostgreSQL y falla la conexion o
apertura de la persistencia. Si `--db` ya es SQLite, no hay segundo fallback.

Si PostgreSQL arranca correctamente y hay `--sqlite-fallback`, el servidor
sincroniza ambos almacenes al inicio. Primero sube a PostgreSQL el ranking y
los snapshots que SQLite pudiera haber guardado durante una caida anterior.
Despues baja desde PostgreSQL hacia SQLite el ranking y los ultimos snapshots.
Asi, si en otro arranque PostgreSQL no esta disponible, el fallback SQLite
tiene una copia reciente aproximada de los datos principales.

Si quieres cerrar un poco el acceso cuando abras el servidor en tu red local,
puedes definir un token:

```bash
FOR_ACCESS_TOKEN=mi-token-local ./run-server.sh
```

Con token activo, crear partidas por HTTP y unirse por WebSocket requiere ese
token. En el cliente puedes pasarlo en la URL:

```text
ws://IP_DE_TU_PC:8080/rooms/ROMA/ws?token=mi-token-local
```

Para clientes o herramientas HTTP tambien se acepta la cabecera:

```text
Authorization: Bearer mi-token-local
```

## Conexion del cliente

La UI pide:

- URL del servidor, por ejemplo `ws://127.0.0.1:8080`.
- alias de sala, por ejemplo `ROMA`.
- alias del jugador, por ejemplo `ABC`.

El primer jugador puede crear la sala desde el dialogo remoto. Al crearla elige
el numero de jugadores y el alias de sala. Ese alias queda reservado mientras la
sala siga activa.

La app muestra este dialogo antes de abrir `PantallaTablero`. El tablero y la
escena 3D solo se cargan despues de que el servidor haya aceptado la union y
devuelto el primer snapshot de partida.

Los demas jugadores no necesitan copiar la URL tecnica `/games/game_0001/ws`;
usan la misma URL base del servidor y el mismo alias de sala. Internamente el
cliente conecta a:

```text
ws://127.0.0.1:8080/rooms/ROMA/ws
```

El alias se valida con `AliasOnline`:

- exactamente 3 caracteres.
- letras o numeros.
- se normaliza a mayusculas.
- no puede duplicarse en la sesion.

El servidor devuelve tambien `gameId` y `sessionToken` en el mensaje
`JoinedMessage`. El cliente genera ademas un `clientId` persistente por
navegador o instalacion de escritorio.
`SesionRemotaController` guarda `gameId`, `sessionToken` y `clientId` en
almacenamiento local por URL de sala y alias. Si se vuelve a conectar al mismo
servidor con el mismo alias, envia el token y el `clientId` para intentar
recuperar la misma plaza incluso despues de cerrar y abrir Chrome o la app.

La identidad real para recuperar plaza es `sessionToken`. El alias es solo el
nombre visible del jugador y no debe usarse como prueba de identidad. Si el
cliente pierde el token, el servidor rechazara el alias como ocupado mientras la
plaza siga reservada.

El servidor asocia cada `sessionToken` al `clientId` que lo recibio. Si alguien
intenta usar un token desde otro terminal, la reconexion se rechaza.

El `sessionToken` solo es valido dentro de la sala que lo emitio. Si el jugador
se desconecta, el servidor mantiene su plaza durante 3 minutos. Si vuelve antes
de ese limite con el token correcto, recupera su jugador. Si pasan mas de 3
minutos, el servidor avisa a los jugadores conectados, suspende la partida y
cierra la sala indicando que la partida ha sido finalizada.

El alias de sala tambien se libera cuando la sala se elimina. Por eso no puede
haber dos salas activas con el mismo alias, pero el mismo nombre se puede volver
a usar mas adelante cuando la partida anterior ya no tenga jugadores conectados.

## API HTTP

El mismo servidor expone endpoints HTTP basicos:

```text
GET  /health       Comprueba estado del servidor.
GET  /leaderboard  Devuelve top 10 global.
GET  /games        Lista partidas en memoria.
POST /games        Crea una partida nueva, opcionalmente con alias de sala.
GET  /games/:id    Devuelve resumen y snapshot de una partida.
DELETE /games/:id  Cierra una partida activa en memoria.
```

### Consultar partidas existentes

Para saber que partidas hay en memoria, abre en el navegador:

```text
http://127.0.0.1:8080/games
```

La respuesta tiene una lista de partidas:

```json
{
  "games": [
    {
      "gameId": "game_0001",
      "players": 2,
      "connectedPlayers": 0,
      "reservedPlayers": 0,
      "currentPlayerId": 0,
      "finished": false
    }
  ]
}
```

Con ese `gameId`, la URL WebSocket de esa partida se forma asi:

```text
ws://127.0.0.1:8080/games/game_0001/ws
```

### Crear una partida nueva

Para crear una partida:

```json
{
  "players": 3,
  "roomAlias": "ROMA"
}
```

Se envia con `POST` a:

```text
http://127.0.0.1:8080/games
```

La respuesta incluye `gameId` y la ruta WebSocket recomendada:

```json
{
  "game": {
    "gameId": "game_0002",
    "roomAlias": "ROMA"
  },
  "wsPath": "/rooms/ROMA/ws"
}
```

La URL final para conectarse desde el cliente se construye uniendo:

```text
ws://127.0.0.1:8080
```

con el `wsPath`:

```text
/games/game_0002/ws
```

Resultado:

```text
ws://127.0.0.1:8080/rooms/ROMA/ws
```

Si el servidor tiene `FOR_ACCESS_TOKEN`, se anade el token:

```text
ws://127.0.0.1:8080/rooms/ROMA/ws?token=mi-token-local
```

### Probar con dos navegadores

1. Arranca el servidor.
2. Arranca la app Flutter web con `flutter run -d chrome`.
3. Copia la URL de Flutter en un segundo navegador o ventana de incognito.
4. El primer cliente crea una sala, por ejemplo `ROMA`, con el numero de
   jugadores deseado.
5. El segundo cliente usa la misma URL base y escribe `ROMA` como alias de sala.

La URL tecnica equivalente seria:

```text
ws://127.0.0.1:8080/rooms/ROMA/ws
```

Cada jugador debe usar un alias de jugador diferente, por ejemplo `ABC` y `ROM`.

### Probar reconexion web con puerto fijo

Para probar reconexion cerrando y abriendo Chrome, es mas fiable arrancar el
frontend como `web-server` con un puerto fijo. Si se usa `flutter run -d chrome`,
la URL temporal puede dejar de servir la app al cerrar Chrome.

Deja el backend abierto:

```powershell
cd backend
.\run-server.ps1
```

Arranca el front web con puerto fijo:

```powershell
cd ..\frontend
flutter run -d web-server --web-hostname localhost --web-port 62166
```

Abre manualmente en Chrome:

```text
http://localhost:62166/
```

Con este flujo puedes cerrar la pestaña o Chrome, volver a abrir la misma URL y
entrar con la misma URL de servidor, alias de sala y alias de jugador antes de
3 minutos. El cliente reutilizara el `sessionToken` guardado en el navegador.

## Protocolo cliente -> servidor

### `join`

```json
{
  "version": 1,
  "type": "join",
  "gameId": "game_0001",
  "roomAlias": "ROMA",
  "createRoom": true,
  "players": 3,
  "sessionToken": "token-si-es-reconexion",
  "clientId": "id-persistente-del-terminal",
  "accessToken": "token-del-servidor-si-esta-activado",
  "playerName": "ABC"
}
```

`gameId`, `roomAlias`, `createRoom`, `players`, `sessionToken`, `clientId` y
`accessToken` son opcionales. En el flujo nuevo se prefiere `roomAlias`: si
`createRoom` es `true` y no existe una sala con ese alias, el servidor la crea.
Si ya existe y no hay `sessionToken`, el servidor rechaza la creacion para
evitar dos salas activas con el mismo nombre. `accessToken` solo es obligatorio
si el servidor se arranco con
`FOR_ACCESS_TOKEN` o `--access-token`.

### `action`

```json
{
  "version": 1,
  "requestId": "accion-001",
  "type": "action",
  "action": "income",
  "payload": {}
}
```

Acciones soportadas:

- `income`
- `buyDeed`
- `build`

### `getLeaderboard`

```json
{
  "type": "getLeaderboard"
}
```

## Protocolo servidor -> cliente

### `joined`

Confirma jugador asignado, envia estado inicial y devuelve `gameId` y
`sessionToken`.

### `snapshot`

Envia el estado serializado de `Juego`.

### `eraSummary`

Envia resumen de era o final.

### `presence`

Informa jugadores conectados/desconectados.

### `leaderboard`

Envia top 10 global.

### `error`

Informa errores de protocolo, turno o validacion.

### `actionAccepted`

Confirma una accion asociada a un `requestId`.

### `actionRejected`

Rechaza una accion asociada a un `requestId` e incluye el motivo.

## Flujo de una accion remota

```text
PantallaTablero
  -> SesionRemotaController.sendAction()
  -> WebSocket
  -> FoundationsServer
  -> GameRoom
  -> Juego.accionIngresos / Juego.comprarParcela / Juego.construir
  -> Juego.consumirResumenPendiente()
  -> guarda evento y snapshot en PartidaRepository
  -> actionAccepted/actionRejected
  -> broadcast snapshot / eraSummary
  -> SesionRemotaController procesa mensaje
  -> PantallaTablero reconstruye estado
```

## Ranking global

Reglas:

- Se guarda en el backend configurado con `--db`: SQLite si se pasa una ruta de archivo, PostgreSQL si se pasa una URL `postgres://` o `postgresql://`.
- Se conserva la mejor puntuacion historica por alias.
- El top 10 se ordena por puntuacion descendente.
- El servidor registra resultados cuando la partida remota termina.

## Persistencia de partidas

La estructura nueva separa una interfaz `PartidaRepository` para guardar:

- partidas creadas.
- snapshots JSON de `Juego`.
- eventos de acciones.

El servidor crea tablas de partidas en la misma BBDD indicada con `--db`:

- SQLite si se pasa una ruta de archivo.
- PostgreSQL si se pasa una URL `postgres://` o `postgresql://`.
- SQLite de respaldo si PostgreSQL falla y se ha configurado
  `--sqlite-fallback`.

Cuando la BBDD principal es PostgreSQL y hay SQLite de respaldo, el servidor
hace una sincronizacion inicial en los dos sentidos: SQLite sube a PostgreSQL
lo que haya guardado durante una caida, y PostgreSQL refresca despues el SQLite.
No es una replica completa en tiempo real, pero permite mantener un respaldo
local util para continuar si PostgreSQL cae.

Las partidas activas se gestionan en memoria mientras el proceso esta vivo y
cada accion deja persistido un evento y un snapshot JSON para auditoria. Al
arrancar, el servidor crea una sala limpia; no reactiva salas antiguas solo por
tener snapshots guardados.

Si se arranca con `--restore-rooms=true` o `FOR_RESTORE_ROOMS=true`, el
servidor rehidrata los snapshots guardados como salas en memoria. Esta opcion
esta pensada para recuperacion o pruebas controladas: las sesiones WebSocket y
los `sessionToken` no se restauran, asi que los jugadores tendran que volver a
entrar como plazas nuevas.

Cuando una sala se queda sin jugadores conectados, el backend conserva la sala
durante la ventana de reconexion de 3 minutos. Si nadie vuelve con un
`sessionToken` valido, la sala se suspende y se elimina de memoria. Si no queda
ninguna sala, la siguiente creacion por HTTP o una nueva conexion a
`/games/game_0001/ws` pueden reutilizar `game_0001` como partida limpia.

Si la sala tenia alias, ese alias se libera al eliminar la sala.

Tablas creadas por el backend:

```text
leaderboard       Mejores puntuaciones por alias.
games             Partidas creadas.
game_snapshots    Ultimo estado JSON de cada partida.
game_events       Historial de eventos y acciones.
schema_migrations Versiones de esquema aplicadas.
```

`SqlitePartidaRepository` y `PostgresPartidaRepository` implementan el mismo
contrato. Eso permite que el servidor cambie de SQLite a PostgreSQL sin cambiar
la logica de salas ni de juego.

## Consideraciones

- El servidor es la autoridad del estado remoto.
- El cliente no debe aplicar reglas remotas localmente como fuente de verdad.
- El backend ya soporta varias salas en memoria mediante `GameRoomManager`.
- La reconexion usa `sessionToken` para recuperar la plaza cuando el cliente
  vuelve a conectarse al mismo servidor con el mismo alias.
- Si un jugador supera 3 minutos desconectado, el servidor suspende la sala,
  notifica que la partida ha sido finalizada y cierra los WebSocket restantes.
- Si cambia `Juego.toJson()` o `Juego.fromJson()`, revisar cliente remoto y servidor.
- Si cambia el protocolo, actualizar `SesionRemotaController`,
  `FoundationsServer`, tests y esta documentacion.
