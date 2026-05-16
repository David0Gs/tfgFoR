# Modo remoto y ranking

El modo remoto usa WebSocket entre el cliente Flutter y un servidor Dart headless.

## Componentes

Cliente:

```text
lib/infrastructure/online/sesion_remota.dart
lib/presentation/screens/pantalla_tablero.dart
```

Servidor:

```text
bin/for_headless_server.dart
```

Dominio compartido:

```text
lib/domain/foundations_of_rome/
lib/domain/alias_online.dart
lib/domain/entrada_leaderboard.dart
```

Ranking:

```text
bin/headless/ranking_global_sqlite.dart
```

## Arranque del servidor

```bash
dart run bin/for_headless_server.dart
```

Argumentos habituales:

```bash
dart run bin/for_headless_server.dart --host=0.0.0.0 --port=8080 --players=3 --db=bin/leaderboard.sqlite3
```

`--db` es obligatorio y selecciona backend por formato:

- ruta de archivo: usa SQLite.
- URL `postgres://` o `postgresql://`: usa PostgreSQL.

Ejemplo PostgreSQL:

```bash
dart run bin/for_headless_server.dart --host=0.0.0.0 --port=8080 --players=3 --db=postgres://usuario:password@localhost:5432/for_db
```

## Conexion del cliente

La UI pide URL y alias. `SesionRemotaController` abre el WebSocket y envia `join`.

El alias se valida con `AliasOnline`:

- exactamente 3 caracteres.
- letras o numeros.
- se normaliza a mayusculas.
- no puede duplicarse en la sesion.

## Protocolo cliente -> servidor

### `join`

```json
{
  "type": "join",
  "playerName": "ABC"
}
```

### `action`

```json
{
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

Confirma jugador asignado y envia estado inicial.

### `snapshot`

Envia el estado serializado de `Game`.

### `eraSummary`

Envia resumen de era o final.

### `presence`

Informa jugadores conectados/desconectados.

### `leaderboard`

Envia top 10 global.

### `error`

Informa errores de protocolo, turno o validacion.

## Flujo de una accion remota

```text
PantallaTablero
  -> SesionRemotaController.sendAction()
  -> WebSocket
  -> for_headless_server.dart
  -> Game.action*
  -> Game.consumePendingSummary()
  -> broadcast snapshot / eraSummary
  -> SesionRemotaController procesa mensaje
  -> PantallaTablero reconstruye estado
```

## Ranking global

Reglas:

- Se guarda en SQLite.
- Se conserva la mejor puntuacion historica por alias.
- El top 10 se ordena por puntuacion descendente.
- El servidor registra resultados cuando la partida remota termina.

## Consideraciones

- El servidor es la autoridad del estado remoto.
- El cliente no debe aplicar reglas remotas localmente como fuente de verdad.
- Si cambia `Game.toJson()` o `Game.fromJson()`, revisar cliente remoto y servidor.
- Si cambia el protocolo, actualizar `SesionRemotaController`, `for_headless_server.dart`, tests y esta documentacion.
