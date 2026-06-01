# Modulos principales de la aplicacion

Este documento explica los tres modulos principales del monorepo:
`frontend/`, `backend/` y `packages/`.

La intencion no es solo enumerar carpetas. El objetivo es entender por que el
proyecto esta dividido asi, que responsabilidad tiene cada parte y como fluye la
informacion cuando una persona juega una partida local o remota.

## 1. Idea general del monorepo

El proyecto esta organizado como un monorepo. Eso significa que en un mismo
repositorio viven varias piezas relacionadas, pero separadas por responsabilidad.

```text
tfgFoR/
  frontend/   Aplicacion Flutter que ve y usa el jugador.
  backend/    Servidor Dart independiente para partidas remotas.
  packages/   Codigo compartido: reglas, modelos y protocolo remoto.
```

La relacion entre los modulos se puede resumir asi:

```text
frontend  -> packages
backend   -> packages
packages  -> no depende ni de frontend ni de backend
```

Esto es una decision importante. `packages/` contiene el conocimiento comun del
juego. El frontend lo usa para jugar partidas locales y mostrar estado. El
backend lo usa para validar acciones remotas y mantener partidas online.

La idea practica es esta:

- `frontend/` sabe mostrar e interactuar.
- `backend/` sabe coordinar clientes remotos y persistir datos globales.
- `packages/` sabe jugar y definir los datos compartidos.

Si las reglas estuvieran copiadas en frontend y backend, cada cambio habria que
hacerlo dos veces. Eso seria peligroso: el cliente podria aceptar una jugada que
el servidor rechaza, o el servidor podria calcular una puntuacion distinta a la
que ve el jugador. Por eso el motor comun vive en `packages/`.

## 2. `packages/`: el nucleo compartido

`packages/` es el modulo mas interno del proyecto. Contiene el paquete Dart
`for_core`.

Cuando una pieza esta en `packages/`, significa que no pertenece solo a la app
Flutter ni solo al servidor. Pertenece al dominio comun del juego o al contrato
compartido entre cliente y servidor.

### 2.1 Que problema resuelve

Imagina que un jugador intenta construir un edificio. Hay muchas preguntas que
responder:

- El jugador tiene esas parcelas?
- El edificio cabe en esa forma?
- Esa construccion esta permitida en la era actual?
- Hay que retirar un edificio anterior?
- Cuantos puntos o monedas genera?
- Termina la era despues de la accion?

Todas esas preguntas son reglas del juego. No deberian depender de Flutter, ni
de botones, ni de WebSocket, ni de SQLite. Por eso viven en `packages/`.

Lo mismo pasa con el protocolo remoto. Si el frontend envia una accion por
WebSocket y el backend la recibe, ambos tienen que ponerse de acuerdo en los
nombres de campos JSON, tipos de mensaje y estructura de datos. Esa definicion
tambien vive en `packages/`.

### 2.2 Que contiene

La estructura principal es:

```text
packages/lib/
  core.dart
  for_core.dart
  protocol.dart
  for_protocol.dart
  core/
  protocol/
```

Los archivos `core.dart` y `protocol.dart` son entradas publicas. En Dart es
comun crear archivos que exportan otros archivos para que el resto del proyecto
no tenga que importar rutas internas largas.

Por ejemplo, en lugar de que cada modulo importe muchos archivos sueltos del
dominio, puede importar una entrada comun del paquete.

`core.dart` representa la parte de reglas y modelos.

`protocol.dart` representa la parte de comunicacion remota.

`for_core.dart` y `for_protocol.dart` son entradas de comodidad con nombres
claros para usar el nucleo o el protocolo por separado.

### 2.3 El dominio de Foundations of Rome

La parte central del juego vive aqui:

```text
packages/lib/core/foundations_of_rome/
```

Dentro aparecen varios tipos de archivos:

```text
game.dart
building_catalog.dart
foundations_of_rome.dart
entities/
errors/
value_objects/
```

El archivo mas importante es `game.dart`. Ahi vive la clase `Juego`. Esta clase
representa el estado de una partida y ofrece operaciones para modificarlo.

Cuando se compra una parcela, se construye un edificio o se recaudan ingresos,
lo correcto es que esa accion pase por `Juego`. Asi se garantiza que las reglas
se aplican igual en local, en bots y en remoto.

`building_catalog.dart` funciona como catalogo del juego. Define informacion de
los edificios: tipo, tamano, forma, coste, puntos, era y datos necesarios para
validar construcciones.

La carpeta `entities/` contiene entidades del dominio. Una entidad es una pieza
del modelo que tiene significado propio dentro del juego:

- `player.dart`: representa un jugador y su estado.
- `building.dart`: representa edificios disponibles o construidos.
- `property.dart`: representa propiedades o parcelas.
- `deed_card.dart`: representa cartas de escritura.

La carpeta `value_objects/` contiene tipos pequenos pero importantes. Un value
object sirve para evitar representar conceptos del dominio con strings o numeros
sueltos sin significado.

Ejemplos:

- `era.dart`: evita tratar una era como un numero cualquiera.
- `player_color.dart`: limita los colores posibles.
- `player_kind.dart`: distingue humano y bot.
- `building_type.dart`: identifica tipos de edificio.

La carpeta `errors/` contiene errores propios del juego. Esto es importante
porque una regla incumplida no es lo mismo que un fallo tecnico. Si un jugador
intenta construir donde no puede, eso es un error de regla. Si se rompe una
conexion de red, eso es otro tipo de problema.

### 2.4 Alias y ranking compartidos

En `packages/lib/core/` tambien hay piezas que no son exactamente tablero, pero
si son datos compartidos:

```text
alias_online.dart
entrada_leaderboard.dart
```

`alias_online.dart` define como debe ser un alias remoto. Por ejemplo, si el
alias debe tener una longitud concreta o solo admitir ciertos caracteres, esa
regla debe ser la misma en cliente y servidor.

Si el frontend aceptara un alias que el backend rechaza, el usuario tendria una
mala experiencia. Por eso la validacion vive en el paquete comun.

`entrada_leaderboard.dart` representa una entrada del ranking global. El backend
la usa para guardar o devolver datos, y el frontend la usa para mostrar esos
datos.

### 2.5 Protocolo remoto

El protocolo remoto vive en:

```text
packages/lib/protocol/remote_protocol.dart
```

Este archivo define como se comunican frontend y backend.

En una partida remota no basta con mandar texto libre por WebSocket. Hace falta
un contrato claro:

- que tipo de mensaje se envia;
- que campos son obligatorios;
- que campos son opcionales;
- como se representa una accion;
- como se responde si la accion se acepta;
- como se informa de errores;
- como se envia un snapshot de la partida.

Ese contrato se define en `packages/` para que ambos lados lo compartan.

Por ejemplo, el frontend puede crear un mensaje de accion usando las clases del
protocolo. El backend puede parsear ese mismo mensaje usando las mismas clases.
Asi se reduce el riesgo de que un lado envie `requestId` y el otro espere
`request_id`, o de que una accion tenga nombres distintos en cliente y servidor.

### 2.6 Que no debe haber en `packages/`

`packages/` debe mantenerse limpio y portable. No debe depender de:

- Flutter;
- widgets;
- WebView;
- WebSocket concreto del cliente;
- HTTP server;
- SQLite;
- PostgreSQL;
- archivos del sistema;
- codigo interno de `frontend/`;
- codigo interno de `backend/`.

Esta regla permite que `packages/` sea reutilizable. Puede ejecutarse en tests
de Dart puro, en Flutter y en el servidor.

### 2.7 Como saber si algo pertenece a `packages/`

Una buena pregunta es:

> Si mañana cambio la interfaz grafica completa, esta pieza seguiria siendo
> necesaria?

Si la respuesta es si, probablemente pertenece a `packages/`.

Otra pregunta util:

> El backend necesita conocer esta regla o este dato para validar partidas
> remotas?

Si la respuesta es si, tambien es candidata a vivir en `packages/`.

Ejemplos claros de cosas que van en `packages/`:

- reglas de construccion;
- calculo de ingresos;
- avance de eras;
- puntuacion;
- entidades del juego;
- formato de mensajes remotos;
- validacion de alias;
- DTOs compartidos.

Ejemplos de cosas que no van en `packages/`:

- un dialogo Flutter;
- un boton del tablero;
- la musica de fondo;
- una conexion WebSocket concreta;
- una consulta SQL;
- un endpoint HTTP.

## 3. `backend/`: el servidor remoto

`backend/` contiene el servidor Dart independiente. Es independiente porque no
se ejecuta dentro de la app Flutter. Puede arrancarse en otra maquina y varios
clientes pueden conectarse a el.

En local puedes tener la app abierta en un navegador o en Windows, mientras el
servidor corre como otro proceso en una terminal.

### 3.1 Que problema resuelve

En una partida local, todo ocurre dentro de la app: la pantalla recibe una
accion, llama a `Juego` y actualiza el estado.

En una partida remota, eso no basta. Si hay varios jugadores conectados desde
dispositivos distintos, alguien tiene que actuar como autoridad comun. Ese papel
lo cumple el backend.

El backend decide:

- que salas existen;
- que jugadores estan dentro de cada sala;
- quien conserva una plaza si se desconecta;
- si una accion llega en el turno correcto;
- si una accion cumple las reglas;
- que snapshot se envia a todos;
- cuando se guarda ranking o partida.

El frontend remoto no debe ser la autoridad final de la partida. Puede mostrar
estado y pedir acciones, pero el backend valida y distribuye el resultado.

### 3.2 Estructura principal

La estructura mas importante es:

```text
backend/
  bin/
    start_server.dart
  lib/
    foundations_server.dart
    config/
    logging/
    persistence/
    rooms/
  test/
```

`bin/start_server.dart` es el punto de entrada. Es el archivo que se ejecuta con:

```bash
dart run bin/start_server.dart --db=leaderboard.sqlite3
```

`lib/foundations_server.dart` contiene el servidor HTTP/WebSocket principal.

`lib/config/` contiene lectura de `.env` y configuracion de arranque.

`lib/rooms/` contiene la logica de salas, jugadores conectados y sesiones.

`lib/persistence/` contiene ranking, snapshots, eventos y adaptadores de base de
datos.

`lib/logging/` contiene un logger simple para mensajes del servidor.

### 3.3 Arranque del servidor

Cuando arrancas el backend, el flujo aproximado es:

```text
start_server.dart
  -> carga .env y variables de entorno
  -> parsea argumentos CLI
  -> valida configuracion
  -> abre repositorios de persistencia
  -> crea FoundationsServer
  -> escucha HTTP y WebSocket
```

La configuracion se define con dos mecanismos:

1. Variables de entorno o archivo `.env`.
2. Argumentos de consola.

Los argumentos de consola tienen prioridad. Esto permite tener una configuracion
por defecto en `.env`, pero sobrescribir algo para una prueba puntual.

Variables principales:

```text
FOR_HOST
FOR_PORT
FOR_PLAYERS
FOR_DB
FOR_SQLITE_FALLBACK
FOR_ACCESS_TOKEN
FOR_RESTORE_ROOMS
```

`FOR_HOST` indica en que direccion escucha el servidor. Para pruebas locales se
puede usar `127.0.0.1`. Para que otros dispositivos de la red se conecten,
normalmente se usa `0.0.0.0`.

`FOR_PORT` indica el puerto.

`FOR_PLAYERS` indica el numero de jugadores por defecto al crear partida.

`FOR_DB` indica donde se guarda la persistencia principal.

`FOR_SQLITE_FALLBACK` permite tener una copia SQLite de respaldo cuando se usa
PostgreSQL.

`FOR_ACCESS_TOKEN` permite proteger la creacion o union a partidas con un token.

`FOR_RESTORE_ROOMS` controla si el servidor restaura snapshots antiguos como
salas activas al arrancar.

### 3.4 `FoundationsServer`

`FoundationsServer` vive en:

```text
backend/lib/foundations_server.dart
```

Es la clase que expone el servidor. Recibe peticiones HTTP, acepta conexiones
WebSocket y delega la logica de partidas en las salas.

Endpoints principales:

```text
GET    /health
GET    /leaderboard
GET    /games
POST   /games
GET    /games/:id
DELETE /games/:id
WS     /games/:id/ws
WS     /rooms/:alias/ws
```

`/health` sirve para comprobar que el servidor esta vivo.

`/leaderboard` devuelve el ranking global.

`/games` permite listar o crear partidas.

`/games/:id` permite consultar una partida concreta.

`/games/:id/ws` es la ruta tecnica de WebSocket por id interno de partida.

`/rooms/:alias/ws` es la ruta comoda para jugadores. En vez de compartir un id
tecnico como `game_0001`, se puede compartir un alias de sala.

### 3.5 Salas y sesiones

La gestion de salas vive en:

```text
backend/lib/rooms/
```

Hay tres conceptos importantes:

```text
GameRoomManager
GameRoom
PlayerSession
```

`GameRoomManager` gestiona el conjunto de salas. Sabe crear partidas, buscar por
id, buscar por alias y eliminar salas cuando ya no deben seguir activas.

`GameRoom` representa una partida concreta. Contiene el estado de `Juego`,
jugadores conectados, sockets abiertos y logica para procesar mensajes.

`PlayerSession` representa la sesion tecnica de un jugador. Esto es distinto
del alias visual. El alias sirve para identificar al jugador en la interfaz. El
`sessionToken` sirve para recuperar la plaza si se desconecta y vuelve a entrar.

Esto es importante porque dos cosas pueden parecer iguales para una persona,
pero no para el servidor:

- "Soy el jugador ROM" es una identidad visual.
- "Tengo este sessionToken emitido por el servidor" es una prueba tecnica de
  continuidad de sesion.

Gracias a esto, el backend puede permitir reconexion sin dejar que otra persona
tome una plaza simplemente escribiendo el mismo alias.

### 3.6 Como se crean las salas

Las salas se crean en `GameRoomManager`. Este gestor mantiene en memoria dos
estructuras principales:

```text
_rooms           Map<String, GameRoom>
_roomIdByAlias   Map<String, String>
```

`_rooms` relaciona un id interno, como `game_0001`, con el objeto `GameRoom` que
representa la partida.

`_roomIdByAlias` relaciona un alias legible de sala, como `ROMA`, con el id
interno real. Esto permite que los jugadores compartan una URL facil de recordar
sin perder un identificador tecnico estable por debajo.

Cuando se crea una sala nueva, el flujo es:

```text
Peticion HTTP POST /games
o mensaje WebSocket join con createRoom=true
  -> FoundationsServer pide una sala a GameRoomManager
  -> GameRoomManager valida numero de jugadores
  -> normaliza y valida alias opcional
  -> genera id interno game_0001, game_0002, ...
  -> crea GameRoom con un Juego nuevo
  -> registra la sala en _rooms
  -> registra el alias en _roomIdByAlias si existe
  -> persiste el snapshot inicial
```

El id interno se genera con un contador incremental:

```text
game_0001
game_0002
game_0003
```

El contador vive en `_nextRoomNumber`. Cada vez que se crea una sala, se usa el
valor actual y luego se incrementa.

Si no queda ninguna sala activa, el gestor vuelve a poner el contador a `1`.
Esto permite reutilizar `game_0001` cuando el servidor se queda sin partidas en
memoria. Esa decision simplifica pruebas y mantiene compatibilidad con la ruta
tecnica antigua.

El alias de sala se valida antes de crearla. Las reglas actuales son:

- longitud entre 3 y 20 caracteres;
- letras, numeros, guion y guion bajo;
- normalizacion a mayusculas;
- no puede duplicar un alias ya reservado.

Por ejemplo, si se crea una sala con alias `roma`, internamente queda como
`ROMA`.

Si el alias ya existe, el backend rechaza la creacion. Esto evita que dos salas
distintas compartan la misma URL comoda.

### 3.7 Formas de llegar a una sala

Hay varias formas de entrar o crear una sala. Todas terminan pasando por la
misma logica de resolucion en `FoundationsServer`.

#### Crear sala por HTTP

Un cliente o herramienta externa puede crear una sala con:

```text
POST /games
```

El cuerpo puede incluir numero de jugadores y alias de sala. El servidor
responde con informacion de la partida y una ruta WebSocket:

```text
/games/game_0001/ws
```

o, si hay alias:

```text
/rooms/ROMA/ws
```

#### Crear sala desde WebSocket

El frontend tambien puede abrir WebSocket directamente y enviar un mensaje
`join` indicando que quiere crear sala. En ese caso, `FoundationsServer` llama a
`_roomForJoin(...)`.

Si el mensaje incluye `roomAlias` y `createRoom=true`, el servidor intenta crear
una sala con ese alias.

Si el alias ya existe y el cliente no esta reconectando con `sessionToken`, el
servidor rechaza la peticion para evitar pisar una sala existente.

#### Entrar por id tecnico

La ruta:

```text
/games/game_0001/ws
```

busca una sala por id interno.

Esta ruta sigue siendo util para tests y compatibilidad. Ademas, hay una regla
especial: si alguien pide `game_0001` y no hay ninguna sala en memoria, el
servidor puede crear una sala por defecto. Esto mantiene funcionando clientes
antiguos que esperaban conectarse siempre a `game_0001`.

#### Entrar por alias de sala

La ruta:

```text
/rooms/ROMA/ws
```

busca primero el alias `ROMA` en `_roomIdByAlias`. Si existe, obtiene el id real
y despues recupera la sala desde `_rooms`.

Esta es la forma mas comoda para usuarios, porque no obliga a compartir ids
tecnicos.

### 3.8 Que guarda cada `GameRoom`

Cada sala es un objeto `GameRoom`. No es solo una etiqueta. Dentro de una sala
viven:

- el id interno de partida;
- el alias opcional de sala;
- un objeto `Juego`;
- las sesiones reservadas por token;
- los sockets conectados;
- timers de expiracion de desconexion;
- repositorios de ranking y partidas;
- estado de si la sala esta suspendida;
- estado de si el ranking final ya se persistio.

Simplificado:

```text
GameRoom
  id: game_0001
  roomAlias: ROMA
  game: Juego
  _sessionsByToken: token -> PlayerSession
  _sessionsBySocket: socket -> PlayerSession
  _expirationTimersByToken: token -> Timer
```

`_sessionsByToken` permite recordar jugadores aunque su socket se desconecte.

`_sessionsBySocket` permite saber que jugador ha enviado un mensaje concreto.

`_expirationTimersByToken` permite cerrar o suspender la sala si una desconexion
dura mas que la ventana permitida.

### 3.9 Reconexion y `sessionToken`

La reconexion remota se gestiona dentro de `GameRoom.join()` y no depende solo
del alias visible del jugador. El alias identifica al jugador en pantalla, pero
la plaza tecnica se recupera con `sessionToken`.

Cuando un jugador entra por primera vez en una sala:

```text
FoundationsServer recibe mensaje join
  -> resuelve o crea la GameRoom
  -> GameRoom.join() valida alias y plaza libre
  -> crea PlayerSession
  -> genera sessionToken
  -> guarda token en _sessionsByToken
  -> asocia socket en _sessionsBySocket
  -> envia joined con playerId, playerName, gameId, roomAlias y sessionToken
```

El token se genera en el servidor con `Random.secure()`: se crean 24 bytes
aleatorios y se codifican con `base64UrlEncode`. Es un token opaco; el cliente
no lo interpreta, solo lo guarda y lo vuelve a enviar al reconectar.

La sesion queda guardada en memoria asi:

```text
_sessionsByToken[token] = PlayerSession(
  token,
  playerId,
  playerName,
  clientId,
)

_sessionsBySocket[socket] = PlayerSession
```

`clientId` es un identificador estable generado por el cliente y guardado en el
dispositivo. Sirve para evitar que un `sessionToken` copiado se use desde otro
terminal. Si llega un join con un token existente pero un `clientId` distinto,
el servidor rechaza la reconexion.

Cuando un jugador se desconecta:

```text
socket se cierra
  -> GameRoom.disconnect(socket)
  -> elimina socket de _sessionsBySocket
  -> conserva PlayerSession en _sessionsByToken
  -> marca disconnectedAt
  -> programa Timer de expiracion
  -> emite presence: playerDisconnected
```

La ventana de reconexion por defecto es de 3 minutos. Durante ese tiempo la
plaza no queda libre para otro alias. La sala conserva el estado de partida y
la sesion tecnica del jugador.

Si el mismo cliente vuelve antes de que expire:

```text
join con sessionToken
  -> GameRoom busca token en _sessionsByToken
  -> valida clientId
  -> _replaceSocket() sustituye el socket anterior si existia
  -> disconnectedAt vuelve a null
  -> cancela el Timer de expiracion
  -> envia joined con el mismo sessionToken
  -> emite presence: playerReconnected
```

Si el token no existe, el backend responde que la sesion ya no es valida para
esa partida. El frontend elimina la sesion recordada y puede intentar entrar de
nuevo sin token. Si la sala estaba llena, entrar sin token no recupera la plaza:
solo el token valido permite volver al mismo `playerId`.

Si el Timer expira antes de la reconexion, la sala se suspende. El backend
envia un error a los sockets conectados, cierra conexiones, cancela timers y
elimina la sala del `GameRoomManager`.

Los `sessionToken` no se escriben en la persistencia de snapshots de partida.
Viven en memoria dentro de `GameRoom`. Si el servidor se reinicia y restaura
una partida desde snapshot, restaura el estado de `Juego`, pero no las sesiones
antiguas de WebSocket.

### 3.10 Logica asincrona y "multihilo"

Es importante matizar el termino multihilo. Este backend no crea un hilo del
sistema operativo por sala ni un hilo por jugador. Tampoco crea un isolate de
Dart por partida.

El servidor usa el modelo habitual de Dart:

```text
un proceso Dart
  -> un isolate principal
  -> event loop
  -> operaciones asincronas con Future/await
  -> callbacks de HttpServer y WebSocket
  -> Timer para expiraciones
```

Esto significa que muchas conexiones pueden estar abiertas a la vez, pero el
codigo Dart de este servidor se ejecuta coordinado por el event loop. Cuando una
operacion espera red, base de datos o lectura de cuerpo HTTP, usa `await` y deja
que el event loop atienda otros eventos.

Por eso el servidor puede manejar varias salas y varios sockets sin crear hilos
manuales.

Un ejemplo mental:

```text
Socket A envia accion
  -> se empieza a procesar
  -> se espera persistencia con await
Mientras tanto:
Socket B puede recibir datos
HTTP /health puede responder
Timer de desconexion puede dispararse
```

Esto no quiere decir que haya varios hilos modificando el mismo `Map` al mismo
tiempo. Al estar en el mismo isolate, no hay memoria compartida entre hilos
paralelos dentro de este codigo. La concurrencia es cooperativa y asincrona.

La consecuencia practica es buena para este proyecto: las estructuras en memoria
como `_rooms`, `_roomIdByAlias`, `_sessionsByToken` o `_sessionsBySocket` son
simples `Map`, sin locks manuales.

Pero tambien hay una responsabilidad: si una funcion hace trabajo pesado de CPU
sin `await`, puede bloquear el event loop. En este proyecto, las operaciones
principales son eventos de red, persistencia y reglas de juego, por lo que el
modelo asincrono encaja bien.

### 3.11 Ciclo de vida de una sala

Una sala suele pasar por estas fases:

```text
1. Creacion
2. Registro en GameRoomManager
3. Union de jugadores
4. Intercambio de acciones y snapshots
5. Desconexion temporal o reconexion
6. Finalizacion, suspension o cierre
7. Eliminacion del gestor
```

En la creacion, se instancia `GameRoom` con un `Juego` nuevo y se guarda el
snapshot inicial.

Durante la union, cada jugador recibe:

- `playerId`;
- alias normalizado;
- `sessionToken`;
- snapshot inicial.

Durante la partida, cada accion aceptada produce:

- registro de evento;
- posibles resumenes pendientes;
- snapshot actualizado;
- broadcast a sockets conectados.

Si un jugador se desconecta, la sala no desaparece al instante. Se marca la
sesion como desconectada y se arranca un `Timer` con la ventana de reconexion.

Si el jugador vuelve antes de que expire el tiempo y presenta el mismo
`sessionToken`, recupera su plaza.

Si el tiempo expira, la sala se suspende. Al suspenderse, el backend cierra
sockets, cancela timers y elimina la sala del `GameRoomManager`.

Tambien se puede cerrar una sala por HTTP con:

```text
DELETE /games/:id
```

En ese caso, `FoundationsServer` llama a `_closeRoom(...)`, cierra sockets,
elimina la sala y libera su alias.

### 3.12 Acciones remotas

Cuando un jugador remoto pulsa una accion, el flujo general es:

```text
frontend
  -> crea mensaje del protocolo
  -> lo envia por WebSocket
backend
  -> recibe mensaje
  -> valida sesion y turno
  -> aplica accion sobre Juego
  -> persiste evento/snapshot
  -> emite snapshot actualizado
frontend
  -> recibe snapshot
  -> actualiza pantalla
```

Observa que el backend tambien usa `Juego`, pero importado desde `packages/`.
Por eso las reglas son las mismas que en una partida local.

El backend no necesita saber como se dibuja un boton ni como se renderiza el
tablero 3D. Solo necesita saber si la accion es valida y cual es el nuevo estado
de la partida.

### 3.13 Persistencia

La persistencia vive en:

```text
backend/lib/persistence/
```

El proyecto separa las interfaces de sus implementaciones.

Interfaces:

```text
ranking_repository.dart
partida_repository.dart
```

Implementaciones SQLite:

```text
sqlite_ranking_repository.dart
sqlite_partida_repository.dart
```

Implementaciones PostgreSQL:

```text
postgres_ranking_repository.dart
postgres_partida_repository.dart
```

Factories:

```text
ranking_repository_factory.dart
partida_repository_factory.dart
```

Una factory es una pieza que decide que implementacion concreta crear. En este
caso, si `FOR_DB` es una ruta de archivo, se usa SQLite. Si es una URL
`postgres://` o `postgresql://`, se usa PostgreSQL.

Esto permite que el resto del backend trabaje contra interfaces. Para
`FoundationsServer`, no deberia importar demasiado si el ranking se guarda en
SQLite o PostgreSQL. Lo importante es que exista un `RankingRepository`.

Tambien existe:

```text
sqlite_backup_sync.dart
```

Su funcion es sincronizar datos entre la base principal y un SQLite de respaldo.
Esto resulta util si PostgreSQL se usa como base principal, pero se quiere
mantener una copia local por seguridad o para fallback.

### 3.14 Modelo de base de datos y conexion

El backend usa repositorios para ocultar si la base real es SQLite o PostgreSQL.
La seleccion se hace a partir de `FOR_DB` o del argumento `--db`:

```text
FOR_DB=data/for.sqlite3
  -> SQLite

FOR_DB=postgres://usuario:password@host:5432/basedatos
  -> PostgreSQL
```

Las factories `ranking_repository_factory.dart` y
`partida_repository_factory.dart` revisan la cadena recibida. Si empieza por
`postgres://` o `postgresql://`, abren PostgreSQL. En cualquier otro caso, la
cadena se interpreta como ruta de archivo SQLite.

En SQLite la conexion se abre con `sqlite3.open(rutaArchivo)`. Si la carpeta no
existe, el repositorio la crea antes con `createSync(recursive: true)`.

En PostgreSQL la conexion se abre parseando la URL:

```text
postgres://usuario:password@host:puerto/nombre_bbdd
```

El backend extrae host, puerto, nombre de base de datos, usuario y password,
crea un `PostgreSQLConnection` y llama a `open()`. El puerto por defecto es
`5432` si la URL no indica otro.

#### Tablas comunes

El modelo se divide en dos bloques:

- ranking global;
- partidas remotas, snapshots y eventos.

La tabla `schema_migrations` existe tanto en ranking como en partidas. Su
objetivo es registrar que el esquema inicial ya se ha aplicado. No es un sistema
de migraciones complejo, pero permite dejar constancia de la version de esquema.

SQLite:

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

PostgreSQL:

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Cada repositorio registra despues su migracion inicial:

```sql
INSERT INTO schema_migrations(version, name, applied_at)
VALUES (..., ..., ...)
ON CONFLICT(version) DO NOTHING;
```

#### Ranking global

El ranking guarda una puntuacion maxima por alias. Si un jugador consigue una
puntuacion menor que su record anterior, no se sobrescribe.

SQLite:

```sql
CREATE TABLE IF NOT EXISTS leaderboard (
  alias TEXT PRIMARY KEY,
  score INTEGER NOT NULL CHECK(score >= 0),
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

PostgreSQL:

```sql
CREATE TABLE IF NOT EXISTS leaderboard (
  alias TEXT PRIMARY KEY,
  score INTEGER NOT NULL CHECK(score >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Para registrar una puntuacion, primero se consulta el valor actual:

```sql
SELECT score FROM leaderboard WHERE alias = ?;
```

En PostgreSQL se usa el mismo concepto con parametros nombrados:

```sql
SELECT score FROM leaderboard WHERE alias = @alias;
```

Si la nueva puntuacion es mayor, se inserta o actualiza:

```sql
INSERT INTO leaderboard(alias, score, updated_at)
VALUES (?, ?, CURRENT_TIMESTAMP)
ON CONFLICT(alias) DO UPDATE SET
  score = excluded.score,
  updated_at = CURRENT_TIMESTAMP
WHERE excluded.score > leaderboard.score;
```

En PostgreSQL:

```sql
INSERT INTO leaderboard(alias, score, updated_at)
VALUES (@alias, @score, NOW())
ON CONFLICT(alias) DO UPDATE SET
  score = EXCLUDED.score,
  updated_at = NOW()
WHERE EXCLUDED.score > leaderboard.score;
```

La consulta del top 10 ordena por puntuacion descendente y, en caso de empate,
por alias:

```sql
SELECT alias, score
FROM leaderboard
ORDER BY score DESC, alias ASC
LIMIT 10;
```

#### Partidas, snapshots y eventos

La tabla `games` guarda la existencia de la partida remota:

SQLite:

```sql
CREATE TABLE IF NOT EXISTS games (
  game_id TEXT PRIMARY KEY,
  player_count INTEGER NOT NULL CHECK(player_count BETWEEN 2 AND 5),
  status TEXT NOT NULL DEFAULT 'open',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

PostgreSQL:

```sql
CREATE TABLE IF NOT EXISTS games (
  game_id TEXT PRIMARY KEY,
  player_count INTEGER NOT NULL CHECK(player_count BETWEEN 2 AND 5),
  status TEXT NOT NULL DEFAULT 'open',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

La tabla `game_snapshots` guarda el estado completo serializado de `Juego`.
SQLite lo guarda como texto JSON; PostgreSQL lo guarda como `JSONB`.

SQLite:

```sql
CREATE TABLE IF NOT EXISTS game_snapshots (
  game_id TEXT PRIMARY KEY,
  snapshot_json TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(game_id) REFERENCES games(game_id)
);
```

PostgreSQL:

```sql
CREATE TABLE IF NOT EXISTS game_snapshots (
  game_id TEXT PRIMARY KEY REFERENCES games(game_id),
  snapshot_json JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Cada vez que se guarda la partida, el snapshot se inserta o se reemplaza:

```sql
INSERT INTO game_snapshots(game_id, snapshot_json, updated_at)
VALUES (?, ?, CURRENT_TIMESTAMP)
ON CONFLICT(game_id) DO UPDATE SET
  snapshot_json = excluded.snapshot_json,
  updated_at = CURRENT_TIMESTAMP;
```

En PostgreSQL:

```sql
INSERT INTO game_snapshots(game_id, snapshot_json, updated_at)
VALUES (@gameId, @snapshot::jsonb, NOW())
ON CONFLICT(game_id) DO UPDATE SET
  snapshot_json = EXCLUDED.snapshot_json,
  updated_at = NOW();
```

Despues se actualiza `games.updated_at` para reflejar actividad reciente:

```sql
UPDATE games SET updated_at = CURRENT_TIMESTAMP WHERE game_id = ?;
```

En PostgreSQL:

```sql
UPDATE games SET updated_at = NOW() WHERE game_id = @gameId;
```

La tabla `game_events` guarda un historial de acciones o eventos remotos:

SQLite:

```sql
CREATE TABLE IF NOT EXISTS game_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  game_id TEXT NOT NULL,
  player_id INTEGER,
  type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(game_id) REFERENCES games(game_id)
);
```

PostgreSQL:

```sql
CREATE TABLE IF NOT EXISTS game_events (
  id BIGSERIAL PRIMARY KEY,
  game_id TEXT NOT NULL REFERENCES games(game_id),
  player_id INTEGER,
  type TEXT NOT NULL,
  payload_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Cada accion aceptada se registra con:

```sql
INSERT INTO game_events(game_id, player_id, type, payload_json)
VALUES (?, ?, ?, ?);
```

En PostgreSQL:

```sql
INSERT INTO game_events(game_id, player_id, type, payload_json)
VALUES (@gameId, @playerId, @type, @payload::jsonb);
```

Para restaurar salas al arrancar, el backend carga snapshots ordenados por id:

```sql
SELECT game_id, snapshot_json, updated_at
FROM game_snapshots
ORDER BY game_id ASC;
```

#### Sincronizacion con SQLite de respaldo

Cuando se usa PostgreSQL como base principal y existe `FOR_SQLITE_FALLBACK`, el
backend puede mantener una copia local SQLite. La sincronizacion copia:

- entradas de ranking, respetando siempre la puntuacion maxima;
- snapshots de partidas, copiando solo si faltan o si el origen es mas nuevo.

El flujo de sincronizacion es bidireccional:

```text
SQLite fallback -> base principal
base principal  -> SQLite fallback
```

Esto permite recuperar datos generados durante una caida temporal de PostgreSQL
y mantener el fallback preparado para futuras incidencias.

### 3.15 Que no debe haber en `backend/`

El backend no debe contener:

- widgets Flutter;
- codigo de interfaz grafica;
- detalles del visor 3D;
- assets visuales;
- logica de botones;
- dependencias internas del frontend.

Si el backend necesita cambiar una regla del juego, esa regla no deberia
implementarse directamente en backend. Deberia modificarse en `packages/` y el
backend la usaria desde ahi.

### 3.16 Como saber si algo pertenece a `backend/`

Una buena pregunta es:

> Esto tiene que ver con coordinar jugadores remotos, red, salas o persistencia
> global?

Si la respuesta es si, probablemente pertenece a `backend/`.

Ejemplos:

- crear una sala remota;
- cerrar una sala;
- aceptar WebSocket;
- validar token de acceso;
- guardar ranking global;
- guardar snapshots de partidas remotas;
- consultar `/health`;
- decidir si se usa SQLite o PostgreSQL.

## 4. `frontend/`: la aplicacion que usa el jugador

`frontend/` contiene la aplicacion Flutter. Es lo que el usuario ve: menu,
tablero, HUD, botones, dialogos, ranking, musica, visor 3D y flujos de partida.

El frontend depende de `packages/`:

```yaml
for_core:
  path: ../packages
```

Esto le permite usar `Juego`, las entidades del dominio y el protocolo remoto.

El frontend no debe depender de `backend/`. Si necesita jugar online, se conecta
por HTTP o WebSocket. No importa clases internas del servidor.

### 4.1 Que problema resuelve

El frontend convierte el estado del juego en una experiencia usable.

El motor `Juego` puede saber que un jugador tiene 5 denarios o que una parcela
pertenece a alguien. Pero eso no basta para una aplicacion. Hace falta:

- mostrar informacion en pantalla;
- permitir seleccionar jugadores;
- mostrar botones de accion;
- responder a clicks sobre el tablero;
- reproducir musica;
- abrir dialogos;
- renderizar modelos 3D;
- guardar partidas locales;
- conectar con un servidor remoto;
- mostrar errores de forma comprensible.

Todo eso vive en `frontend/`.

### 4.2 Arranque de Flutter

Los archivos de arranque son:

```text
frontend/lib/main.dart
frontend/lib/app_entrypoint.dart
frontend/lib/application_config.dart
```

`main.dart` es el punto de entrada. Normalmente debe ser pequeno. Su trabajo es
arrancar la app.

`app_entrypoint.dart` contiene el arranque real de la aplicacion Flutter. Aqui se
preparan servicios, callbacks, rutas principales y el estado inicial necesario
para mostrar el menu y navegar al tablero.

`application_config.dart` agrupa configuraciones dependientes de plataforma.
Esto puede incluir ventana desktop, inicializacion de reproductores o ajustes
necesarios antes de que la UI empiece a trabajar.

La razon de separar estos archivos es mantener `main.dart` limpio. Si todo el
arranque viviera en `main.dart`, ese archivo acabaria mezclando plataforma,
servicios, rutas y UI.

### 4.3 Pantallas y widgets

La capa visual vive en:

```text
frontend/lib/presentation/
```

Dentro hay:

```text
for_theme.dart
screens/
widgets/
```

`for_theme.dart` centraliza colores, estilos y decisiones visuales comunes.

`screens/` contiene pantallas completas:

```text
pantalla_menu_principal.dart
pantalla_tablero.dart
```

`pantalla_menu_principal.dart` es la entrada del usuario. Desde aqui se puede
iniciar partida local, conectarse a una partida remota, consultar ranking,
abrir creditos o acceder a informacion adicional.

`pantalla_tablero.dart` es la pantalla mas importante durante la partida.
Coordina tablero, HUD de jugadores, mercado de escrituras, acciones,
selecciones, overlays, mensajes, resumenes y visor 3D.

`widgets/` contiene piezas reutilizables. Por ejemplo:

- barra de herramientas del tablero;
- botones de toolbar;
- HUD de jugadores;
- tarjetas de informacion de jugador;
- mercado de escrituras;
- catalogo de edificios;
- indicador de era;
- dialogo de ranking remoto;
- dialogo de union remota;
- resumen de partida;
- overlay de seleccion de anclaje;
- miniatura 3D de edificio.

La idea es que una pantalla completa no tenga que contener todo el codigo visual
en un unico archivo enorme. Los widgets permiten dividir la interfaz en piezas
mas pequenas y entendibles.

### 4.4 Controlador del tablero

El archivo:

```text
frontend/lib/controlador_tablero.dart
```

conecta la pantalla con el visor 3D. Es una pieza de coordinacion.

Cuando el usuario pulsa sobre una parcela o cuando la app necesita resaltar una
zona, ese evento tiene que traducirse entre Flutter y la escena 3D. El
controlador ayuda a mantener esa comunicacion ordenada.

Este archivo no debe convertirse en el motor de reglas. Si hay que decidir si
una construccion es legal, la respuesta debe venir de `Juego` en `packages/`.

### 4.5 Capa de aplicacion

La capa de aplicacion vive en:

```text
frontend/lib/application/
```

Contiene logica que no es puramente visual, pero que tampoco pertenece al nucleo
compartido.

Subcarpetas:

```text
bots/
local_game/
```

`local_game/` contiene la configuracion de partidas locales. Sirve para preparar
numero de jugadores y tipo de cada jugador antes de crear la partida.

`bots/` contiene la logica de jugadores automaticos. Los bots no deberian tener
reglas propias separadas del juego. Lo correcto es que decidan una accion y la
ejecuten sobre `Juego`, igual que una accion humana.

Archivos relevantes:

```text
foundations_of_rome_bot_service.dart
local_bot_turn_runner.dart
local_bots.dart
bot_planned_action.dart
bot_action_type.dart
build_candidate.dart
buy_candidate.dart
```

Un bot necesita responder preguntas como:

- puedo comprar alguna parcela?
- puedo construir algun edificio?
- que construccion me conviene mas?
- si no puedo hacer nada util, recaudo ingresos?

La capa de bots organiza esa decision, pero las reglas finales siguen estando en
`packages/`.

### 4.6 Infraestructura del frontend

La infraestructura vive en:

```text
frontend/lib/infrastructure/
```

Aqui se colocan adaptadores hacia cosas externas o dependientes de plataforma.
No son reglas del juego ni widgets puros.

#### Audio

```text
frontend/lib/infrastructure/audio/
```

Archivos:

```text
audio_service.dart
audio_service_contract.dart
audio_service_native.dart
audio_service_web.dart
```

El audio puede comportarse distinto en web y en plataformas nativas. Por eso se
usa una fachada comun. Las pantallas hablan con `AudioService`, pero no tienen
que saber que implementacion concreta se esta usando.

#### Persistencia local

```text
frontend/lib/infrastructure/persistence/
```

Archivos:

```text
persistencia_partida.dart
persistencia_partida_stub.dart
persistencia_partida_web.dart
```

Esta persistencia es local al usuario. Sirve para guardar o cargar partidas
desde la app. No es lo mismo que el ranking global del backend.

Es importante separar ambas ideas:

- guardado local de partida: pertenece al frontend;
- ranking global y snapshots remotos: pertenecen al backend.

#### Cliente remoto

```text
frontend/lib/infrastructure/sesion_remota.dart
frontend/lib/infrastructure/remote_session_store.dart
frontend/lib/infrastructure/remote_session_store_stub.dart
frontend/lib/infrastructure/remote_session_store_web.dart
```

`sesion_remota.dart` es el cliente remoto de la app. Se encarga de conectar con
el backend, enviar mensajes por WebSocket, recibir snapshots, gestionar errores
y mantener datos de sesion.

`remote_session_store_*` permite recordar informacion de reconexion. En web,
por ejemplo, puede ser necesario cerrar una pestana y volver a abrirla. Si el
token de sesion sigue disponible y la ventana de reconexion no ha caducado, el
cliente puede intentar recuperar su plaza.

### 4.7 Visor 3D

El visor 3D vive en:

```text
frontend/lib/visor_3d/
```

Esta parte integra Three.js dentro de la aplicacion Flutter.

Archivos principales:

```text
visor_3d_widget.dart
escena_threejs.dart
camara_config.dart
factory_plataforma.dart
interfaz_controlador.dart
plataformas/
```

`visor_3d_widget.dart` es el widget que Flutter coloca en pantalla.

`escena_threejs.dart` contiene la escena que representa tablero, marcadores,
parcelas y edificios.

La escena usa render bajo demanda. Esto significa que Three.js no renderiza en
bucle permanente durante la partida; solicita frames cuando cambian la camara,
los modelos, la visibilidad o hay animaciones activas.

Los GLB se cachean por URL para no recargar el mismo archivo constantemente.
Cuando un modelo deja de existir en escena y ningun otro objeto usa su GLB, la
cache libera geometria, materiales y texturas del modelo base.

Para los clicks sobre edificios construidos, la escena no intersecta el modelo
GLB completo. `TableroController` sincroniza colliders invisibles simples por
cada casilla ocupada y Three.js usa esos colliders para devolver el mismo id de
edificio. Esto reduce coste de raycast sin cambiar la seleccion ni la
sustitucion de edificios.

`camara_config.dart` agrupa configuracion de camara.

`factory_plataforma.dart` decide que implementacion usar segun la plataforma.

`interfaz_controlador.dart` define como se comunican otras partes de la app con
el visor sin depender de detalles internos.

La carpeta `plataformas/` separa implementaciones para web, escritorio y movil.
Esto es necesario porque embeber contenido web o Three.js no funciona igual en
todas las plataformas.

### 4.8 Assets

El frontend tambien contiene assets:

```text
frontend/assets/
  models/
  thumbnails/
  pics/
  music/
  texts/
```

`models/` contiene modelos GLB del tablero, marcadores y edificios.

`thumbnails/posters/` contiene posters `.webp` para mostrar edificios en
movil. En escritorio puede haber videos `.mp4` de miniatura si se incluyen en
el build; Android usa solo posters para evitar reproductores de video durante
el scroll.

`pics/` contiene imagenes de interfaz, fondos e iconos.

`music/` contiene musica.

`texts/` contiene textos cargados por la aplicacion, como instrucciones o
agradecimientos.

Estos assets pertenecen al frontend porque forman parte de la experiencia visual
y sonora del usuario.

### 4.9 Que no debe haber en `frontend/`

El frontend no debe contener:

- consultas SQL del ranking global;
- implementaciones internas de repositorios del backend;
- reglas duplicadas de `Juego`;
- logica de autoridad para partidas remotas;
- clases internas de `backend/`.

Puede tener validaciones de interfaz para mejorar la experiencia, pero la regla
importante debe estar en `packages/` o en el backend cuando se trate de
autoridad remota.

### 4.10 Como saber si algo pertenece a `frontend/`

Una buena pregunta es:

> Esto existe porque el usuario necesita verlo, pulsarlo, escucharlo o
> interactuar con ello?

Si la respuesta es si, probablemente pertenece a `frontend/`.

Ejemplos:

- pantalla de menu;
- dialogo de conexion remota;
- HUD de jugadores;
- selector de numero de jugadores;
- visor 3D;
- musica;
- persistencia local de partida;
- cliente WebSocket de la app;
- widgets de ranking.

## 5. Como colaboran los tres modulos

La division en modulos se entiende mejor viendo flujos reales.

### 5.1 Partida local

En una partida local, no hace falta backend. Todo ocurre dentro de la app, pero
las reglas siguen estando en `packages/`.

```text
Usuario pulsa una accion
  -> frontend/presentation captura el evento
  -> frontend decide que accion quiere ejecutar
  -> packages/Juego valida y modifica estado
  -> frontend actualiza HUD, mensajes y visor 3D
```

Ejemplo: el jugador compra una parcela.

1. La persona pulsa una carta o parcela en la interfaz.
2. La pantalla interpreta la intencion.
3. Se llama a una accion de `Juego`.
4. `Juego` comprueba si la compra es valida.
5. Si es valida, cambia propietario, monedas o marcadores.
6. La pantalla vuelve a pintar el estado.
7. El visor 3D resalta o actualiza elementos.

### 5.2 Partida local con bots

Con bots, el flujo es parecido, pero la intencion no viene de un click humano.

```text
frontend/application/bots decide accion
  -> packages/Juego valida y ejecuta
  -> frontend/presentation muestra resultado
```

El bot no deberia saltarse las reglas. Solo decide que intentar hacer. La
autoridad sobre si eso se puede hacer sigue siendo `Juego`.

### 5.3 Partida remota

En una partida remota, el backend se convierte en autoridad.

```text
Usuario pulsa accion
  -> frontend crea ActionRequest
  -> packages/protocol serializa mensaje
  -> frontend envia WebSocket
  -> backend recibe mensaje
  -> backend valida sesion y turno
  -> backend aplica accion en packages/Juego
  -> backend guarda snapshot/evento
  -> backend envia snapshot a clientes
  -> frontend actualiza pantalla
```

Aqui el frontend no decide por si solo que la partida ha cambiado. Espera el
snapshot del servidor. Esto evita que dos clientes terminen con estados
distintos.

### 5.4 Ranking global

El ranking global pertenece al backend.

```text
backend/persistence guarda ranking
  -> backend expone /leaderboard
  -> frontend consulta o recibe datos
  -> frontend muestra dialogo de ranking
```

El tipo de dato del ranking esta en `packages/`, porque frontend y backend lo
comparten. Pero la persistencia real del ranking vive en `backend/`.

## 6. Donde tocar segun el cambio

Esta tabla sirve como guia rapida.

```text
Cambio que quieres hacer                         Modulo habitual
------------------------------------------------ ----------------------------
Regla de compra, construccion o puntuacion       packages/
Nueva entidad del juego                          packages/
Nuevo campo de protocolo WebSocket               packages/lib/protocol/
Validacion de alias remoto                       packages/
Pantalla nueva                                   frontend/lib/presentation/
Widget reutilizable                              frontend/lib/presentation/widgets/
Cambio visual del tablero                        frontend/lib/presentation/ o visor_3d/
Logica de bot                                    frontend/lib/application/bots/
Guardado local de partida                        frontend/lib/infrastructure/persistence/
Cliente WebSocket Flutter                        frontend/lib/infrastructure/sesion_remota.dart
Endpoint HTTP nuevo                              backend/lib/foundations_server.dart
Gestion de salas                                 backend/lib/rooms/
Reconexion y sessionToken                        backend/lib/rooms/ y frontend/infrastructure/
Ranking global                                   backend/lib/persistence/
SQLite/PostgreSQL                                backend/lib/persistence/
Configuracion de arranque servidor               backend/lib/config/
```

## 7. Reglas mentales para mantener el proyecto sano

La arquitectura no es solo una forma bonita de ordenar carpetas. Sirve para
evitar errores.

Primera regla:

```text
Las reglas del juego viven en packages.
```

Si una regla se duplica en frontend, tarde o temprano se desincronizara.

Segunda regla:

```text
El backend es la autoridad de la partida remota.
```

El frontend remoto puede pedir acciones, pero no deberia inventar el estado
final sin confirmacion del servidor.

Tercera regla:

```text
El frontend se ocupa de experiencia de usuario.
```

Pantallas, dialogos, audio, visor 3D y gestos pertenecen al frontend.

Cuarta regla:

```text
El protocolo compartido vive en packages.
```

Si cambia el JSON remoto, debe cambiar en un sitio que cliente y servidor puedan
usar.

Quinta regla:

```text
La persistencia global vive en backend.
```

El ranking global no debe depender de un cliente concreto.

## 8. Planificacion y desarrollo

El desarrollo se organizo en tres meses principales: marzo, abril y mayo. La
planificacion no fue completamente lineal, porque algunas tareas se revisaron
varias veces al aparecer necesidades de rendimiento, compatibilidad movil o
mejoras de documentacion. Aun asi, el flujo general puede resumirse asi:

```mermaid
gantt
    title Planificacion del desarrollo
    dateFormat  YYYY-MM-DD
    axisFormat  %d/%m

    section Marzo
    Analisis inicial y alcance              :a1, 2026-03-01, 2026-03-07
    Modelo de dominio en packages           :a2, 2026-03-05, 2026-03-17
    Reglas base de partida local            :a3, 2026-03-12, 2026-03-31
    Primeras pantallas Flutter              :a4, 2026-03-20, 2026-03-31

    section Abril
    Visor 3D y sincronizacion tablero       :b1, 2026-04-01, 2026-04-16
    Bots locales y flujo de turnos          :b2, 2026-04-10, 2026-04-20
    Backend HTTP/WebSocket                  :b3, 2026-04-15, 2026-04-30
    Ranking global y persistencia           :b4, 2026-04-22, 2026-05-05

    section Mayo
    Conexion remota y reconexion            :c1, 2026-05-01, 2026-05-12
    Adaptacion movil y rendimiento          :c2, 2026-05-08, 2026-05-24
    Builds, despliegue y assets             :c3, 2026-05-15, 2026-05-27
    Pruebas, validacion y documentacion     :c4, 2026-05-18, 2026-05-31
```

En marzo se centro el trabajo en la base del proyecto: separacion del monorepo,
definicion de entidades, reglas principales del juego, validaciones de
construccion y primeras pantallas de la aplicacion. El objetivo fue que la
partida local pudiera avanzar con una estructura de codigo mantenible.

En abril se amplio la aplicacion con el visor 3D, la sincronizacion visual del
tablero, los bots locales y el backend remoto. Tambien se empezo a consolidar
la persistencia, el ranking global y el protocolo comun entre cliente y
servidor.

En mayo el foco paso a integracion, rendimiento y cierre: conexion remota,
reconexion con `sessionToken`, adaptacion a movil, optimizacion de assets,
reduccion de carga en miniaturas, mejoras en memoria del visor 3D, builds para
Android/Windows/web, pruebas manuales y documentacion final.

## 9. Pruebas y validacion

Durante el desarrollo se han usado dos tipos de validacion:

- analisis estatico, para detectar errores de tipos, imports, APIs rotas o
  codigo que no cumple las reglas del analizador;
- tests automaticos, para comprobar reglas de juego, protocolo remoto,
  sesiones, persistencia y comportamiento de servicios.

Como el proyecto esta dividido en `packages/`, `backend/` y `frontend/`, las
pruebas se ejecutan por modulo. Esto ayuda a localizar el origen de un fallo y
evita mezclar reglas compartidas, servidor y experiencia visual.

### 9.1 Validacion de `packages/`

`packages/` contiene reglas compartidas y protocolo. Es el primer modulo que
conviene validar cuando cambia una entidad, una regla o un mensaje remoto.

```bash
cd packages
dart analyze
dart test
```

Los tests actuales cubren especialmente `protocolo_remoto_test.dart`, donde se
comprueba que los mensajes remotos se serializan y se parsean correctamente:
join con token opcional, acciones con payload y mensajes de ranking.

Esta validacion es importante porque tanto `frontend/` como `backend/` dependen
del mismo contrato. Si el protocolo cambia aqui y los tests pasan, se reduce el
riesgo de que cliente y servidor hablen formatos distintos.

### 9.2 Validacion de `backend/`

`backend/` se valida con:

```bash
cd backend
dart analyze
dart test
```

Durante el desarrollo se han usado estos tests para comprobar:

- arranque de servidor y configuracion por argumentos o variables de entorno;
- lectura de `.env`;
- endpoints HTTP como health, creacion/listado/cierre de partidas y ranking;
- WebSocket remoto;
- creacion de salas con alias;
- union de jugadores;
- reconexion con `sessionToken`;
- rechazo de tokens de otro terminal mediante `clientId`;
- expiracion de sesiones desconectadas;
- sala llena y alias duplicados;
- aceptacion/rechazo de acciones remotas;
- persistencia de snapshots y eventos en SQLite;
- repositorios de ranking y factory de repositorios;
- sincronizacion de backup SQLite cuando existe almacenamiento principal.

Los tests mas representativos estan en `foundations_server_test.dart`, porque
ejercitan el servidor completo: abren sockets, envian mensajes `join`, simulan
reconexiones y comprueban snapshots o errores. Para persistencia se usan tests
especificos como `partida_repository_sqlite_test.dart`,
`ranking_repository_sqlite_test.dart` y `sqlite_backup_sync_test.dart`.

### 9.3 Validacion de `frontend/`

`frontend/` se valida con:

```bash
cd frontend
flutter analyze
flutter test
```

Durante el desarrollo se ha usado mucho `flutter analyze` despues de cambios en
interfaces compartidas del visor 3D, controladores, persistencia o widgets. Es
especialmente util cuando se modifica una interfaz como `I3DViewerController`,
porque obliga a actualizar todas las implementaciones de web, escritorio y
movil.

Los tests de frontend cubren partes de comportamiento que no son puramente
visuales:

- `build_validation_test.dart`: validaciones de construccion, sustitucion de
  edificios, rotaciones y extraccion de coordenadas desde ids visuales;
- `local_bot_controller_test.dart`: decisiones basicas de bots locales;
- `player_kind_persistence_test.dart`: guardado y carga de jugadores humanos o
  bots;
- `sesion_remota_controller_test.dart`: creacion de sala remota, reutilizacion
  de `sessionToken`, olvido de tokens caducados y tratamiento de finalizacion
  remota.

Las pruebas visuales del visor 3D, rendimiento en movil, miniaturas, memoria y
fluidez se han validado principalmente de forma manual en Windows, emulador y
dispositivo Android real. En esos casos se han usado logs de rendimiento,
`adb logcat`, pruebas de scroll en bandeja de edificios, construccion progresiva
de edificios y comprobacion de cierres por memoria.

### 9.4 Cuando ejecutar cada cosa

Cuando se cambia algo en `packages/`, conviene probar los tres modulos, porque
el cambio puede afectar a frontend y backend.

```bash
cd packages
dart analyze
dart test

cd ../backend
dart analyze
dart test

cd ../frontend
flutter analyze
flutter test
```

Si solo se cambia documentacion, no hace falta ejecutar toda la suite. Cuando se
cambia protocolo, reglas, sesiones o persistencia, conviene ejecutarla.

Si el cambio afecta solo al visor 3D o a UI movil, `flutter analyze` es el
minimo recomendable, y despues conviene hacer una prueba manual en el dispositivo
objetivo porque rendimiento, WebView, memoria GPU y decodificacion de assets no
siempre quedan cubiertos por tests unitarios.

## 10. Resumen final

El monorepo separa tres responsabilidades:

`packages/` es el conocimiento compartido. Define reglas, entidades, errores,
alias, ranking y protocolo remoto. Debe ser Dart puro.

`backend/` es el servidor remoto. Gestiona salas, WebSocket, endpoints HTTP,
sesiones, reconexion, ranking y persistencia. Usa `packages/` para aplicar las
mismas reglas que la app.

`frontend/` es la experiencia del jugador. Muestra pantallas, tablero, visor 3D,
audio, dialogos, bots locales, guardado local y conexion remota. Usa `packages/`
para jugar y hablar el mismo protocolo que el backend.

Cuando entiendes esta separacion, el proyecto se vuelve mucho mas facil de
mantener. Antes de cambiar codigo, la pregunta clave es:

> Esto es regla compartida, servidor remoto o experiencia de usuario?

La respuesta normalmente te dira en que modulo empezar.

## 11. Despliegue resumido

El despliegue de la aplicacion depende de que parte se quiera distribuir. El
frontend se compila como aplicacion de jugador, mientras que el backend se
ejecuta aparte como servidor remoto. `packages/` no se despliega por separado:
se incorpora como dependencia compartida dentro de frontend y backend.

### 11.1 Aplicacion Android

La version Android se genera desde `frontend/`:

```bash
cd frontend
flutter build apk --release --split-per-abi
```

Este comando crea APK separados por arquitectura. Para moviles actuales Android,
normalmente interesa `app-arm64-v8a-release.apk`. El APK incluye la app Flutter,
assets declarados en `pubspec.yaml`, modelos, posters de miniaturas, musica,
imagenes y el visor 3D embebido.

El backend no se incluye dentro del APK. Si se quiere ranking global o partida
remota, el movil debe conectarse a un servidor externo accesible por red.

### 11.2 Aplicacion Windows

La version Windows tambien se compila desde `frontend/`:

```bash
cd frontend
flutter build windows --release
```

El resultado queda dentro de `build/windows/x64/runner/Release/`. Para
distribuirlo hay que conservar el `.exe` junto con sus DLL y carpetas generadas,
no solo copiar el ejecutable aislado.

Si Windows bloquea `flutter clean` o una build, suele ser porque la app anterior
o algun proceso de Flutter sigue usando archivos de `build/`.

### 11.3 Frontend web

La version web del frontend se genera tambien desde `frontend/`:

```bash
cd frontend
flutter build web --release
```

El resultado queda en `build/web/`. Esa carpeta es la que se publica en un
hosting estatico o en un servidor web. A diferencia de Android y Windows, la
version web se ejecuta en el navegador y carga los assets desde el propio sitio
publicado.

Si la version web necesita ranking global o partidas remotas, debe apuntar a un
backend accesible desde el navegador. En produccion conviene servir el frontend
por HTTPS y usar tambien un backend HTTPS/WSS compatible para evitar bloqueos
del navegador por contenido mixto.

### 11.4 Servidor backend

El backend se despliega aparte desde `backend/`. Antes de publicarlo conviene
validarlo:

```bash
cd backend
dart analyze
dart test
```

Despues puede ejecutarse con Dart, configurando host, puerto, base de datos y
token de acceso si se quiere proteger el servidor:

```bash
dart run bin/start_server.dart --host=0.0.0.0 --port=8080 --db=sqlite://data/for.sqlite3
```

En produccion, el backend debe estar en una maquina accesible por los clientes.
Si se usa desde moviles fuera del ordenador local, no vale `localhost`: hay que
usar una IP o dominio alcanzable desde esos dispositivos.

### 11.5 Relacion entre app y servidor

La app puede funcionar sin backend para partidas locales. El backend solo es
necesario para:

- crear o unirse a partidas remotas;
- reconexion de jugadores remotos;
- ranking global;
- persistencia centralizada de partidas remotas.

Por eso `/server` o `backend/` no debe empaquetarse dentro del APK ni dentro de
la build Windows. Se mantiene como proceso independiente y la app se comunica
con el mediante HTTP/WebSocket.

## 12. Conclusiones y lineas futuras

El proyecto ha evolucionado desde una aplicacion local hasta una arquitectura
modular con cliente Flutter, motor de reglas compartido y servidor remoto. La
separacion entre `frontend/`, `backend/` y `packages/` permite que las reglas
del juego se mantengan en un unico lugar y que tanto la app local como el modo
online usen el mismo criterio de validacion.

La aplicacion ya cubre los flujos principales: partida local, bots, construccion
de edificios, visor 3D, guardado local, ranking global, partidas remotas,
reconexion de jugadores y builds para distintas plataformas. Tambien se han
aplicado optimizaciones importantes para movil, como miniaturas estaticas,
reduccion de assets, render bajo demanda, cache controlada de GLB y colliders
simples para clicks sobre edificios.

Como lineas futuras, el primer bloque de mejora estaria en rendimiento y
estabilidad movil. Aunque se han reducido varios costes, seria conveniente
seguir midiendo memoria real en dispositivo, revisar modelos GLB pesados,
automatizar pruebas de carga del visor 3D y valorar niveles de detalle o
versiones simplificadas de modelos para partidas avanzadas.

Otra linea seria reforzar el despliegue online. El backend actual es suficiente
para pruebas y partidas controladas, pero una publicacion real podria requerir
HTTPS/WSS, configuracion de dominio, logs persistentes, copias de seguridad,
monitorizacion, despliegue en contenedor y pruebas de carga con muchas salas
simultaneas.

Tambien se podria ampliar la calidad de pruebas. Ahora existen tests de reglas,
protocolo, backend, persistencia, bots y sesion remota, pero seria positivo
sumar pruebas de integracion completas cliente-servidor, pruebas de regresion
para partidas guardadas antiguas y pruebas automatizadas de interfaz en los
flujos mas criticos.

En experiencia de usuario, las mejoras futuras podrian centrarse en pulir la
interfaz movil, hacer mas clara la seleccion/sustitucion de edificios, anadir
opciones graficas segun potencia del dispositivo y mejorar la informacion de
conexion remota para que el usuario entienda mejor errores de red, servidor o
sesion caducada.

Finalmente, el proyecto queda preparado para crecer porque la base esta
separada por responsabilidades: si cambia una regla, se toca `packages/`; si
cambia el online, se toca `backend/`; y si cambia la experiencia visual, se toca
`frontend/`. Esa division es la principal conclusion tecnica del desarrollo.

## 13. Bibliografia y herramientas utilizadas

Esta seccion reune las fuentes tecnicas, librerias y herramientas usadas como
apoyo durante el desarrollo. La bibliografia puede adaptarse despues al formato
exigido por el centro, pero queda agrupada por ambito para facilitar su revision.

### 13.1 Referencias principales del proyecto

- *Foundations of Rome*, juego de mesa original de Arcane Wonders, usado como
  base tematica y mecanica para la adaptacion digital.
- Materiales y reglas del juego fisico original consultados para modelar
  acciones, edificios, eras, puntuacion y flujo de partida.
- Documentacion propia del repositorio, especialmente los documentos de
  arquitectura, modo remoto, despliegue, visor 3D, flujo de datos y memoria del
  TFG.

### 13.2 Lenguajes, frameworks y plataformas

- Flutter. Documentacion oficial: https://docs.flutter.dev/
- Flutter API Reference: https://api.flutter.dev/
- Dart. Documentacion oficial: https://dart.dev/docs
- Dart API Reference: https://api.dart.dev/
- Android Studio y Android SDK. Documentacion oficial:
  https://developer.android.com/studio
- Android Debug Bridge (`adb`), usado para pruebas con dispositivo/emulador y
  lectura de logs.
- Windows, PowerShell y herramientas de compilacion de escritorio para generar
  la aplicacion Windows.

### 13.3 Renderizado 3D, WebView y graficos

- Three.js. Documentacion oficial: https://threejs.org/docs/
- WebGL y canvas del navegador como base de renderizado para Three.js.
- `GLTFLoader`, `DRACOLoader`, `EXRLoader`, `OrbitControls` y utilidades de
  Three.js usadas en el visor 3D.
- Blender. Documentacion oficial: https://docs.blender.org/
- Formato GLB/glTF para modelos 3D usados por tablero, edificios, marcadores y
  escenario.
- FFmpeg. Documentacion oficial: https://www.ffmpeg.org/documentation.html
- Herramientas de optimizacion de assets para reducir peso de modelos, musica,
  videos y miniaturas.

### 13.4 Bases de datos, servidor y comunicacion

- PostgreSQL. Documentacion oficial: https://www.postgresql.org/docs/
- SQLite. Documentacion oficial: https://www.sqlite.org/docs.html
- WebSocket como protocolo de comunicacion en tiempo real entre cliente y
  backend.
- HTTP para endpoints de salud, partidas y ranking global.
- JSON como formato de serializacion de snapshots, acciones remotas y mensajes
  de protocolo.

### 13.5 Paquetes y dependencias del frontend

El frontend usa paquetes de Flutter/Dart declarados en `frontend/pubspec.yaml`:

- `flutter_inappwebview` y `flutter_inappwebview_windows`, para integrar el
  visor Three.js en WebView y WebView2.
- `window_manager`, para configuracion de ventana en escritorio.
- `pointer_interceptor`, para coordinar overlays Flutter con contenido web.
- `web_socket_channel`, para la conexion remota por WebSocket.
- `url_launcher`, para abrir enlaces externos.
- `audioplayers`, para musica y audio.
- `video_player` y `fvp`, para miniaturas de video en escritorio.
- `path_provider`, para rutas de guardado local en movil/escritorio.
- `flutter_launcher_icons`, para generar iconos de la aplicacion.
- `flutter_lints` y `flutter_test`, para analisis estatico y pruebas.

### 13.6 Paquetes y dependencias del backend

El backend usa dependencias declaradas en `backend/pubspec.yaml`:

- `postgres`, para conectarse a PostgreSQL.
- `sqlite3`, para persistencia local y fallback SQLite.
- `test`, para pruebas automaticas.
- `lints`, para reglas de analisis estatico en Dart.

### 13.7 Herramientas de desarrollo y documentacion

- Visual Studio Code. Documentacion oficial: https://code.visualstudio.com/docs
- Git. Documentacion oficial: https://git-scm.com/doc
- Flutter CLI, Dart CLI y comandos de build/analyze/test.
- Android Studio Emulator, usado para pruebas de interfaz y comportamiento en
  Android.
- `adb logcat`, usado para analizar errores, cierres, memoria y mensajes de
  rendimiento en Android.
- diagrams.net / draw.io, usado para diagramas de arquitectura, flujo y
  explicacion visual del sistema. Sitio oficial: https://www.drawio.com/
- Mermaid, usado para diagramas embebidos en Markdown, incluido el diagrama de
  Gantt de planificacion.
- Markdown, usado para la documentacion tecnica del proyecto.

### 13.8 Recursos visuales y sonoros

- Modelos GLB de tablero, edificios, escenario y marcadores incluidos en
  `frontend/assets/models/`.
- Imagenes de interfaz, icono, splash y fondos incluidos en
  `frontend/assets/pics/`.
- Miniaturas y posters incluidos en `frontend/assets/thumbnails/`.
- Pista de musica incluida en `frontend/assets/music/`.
- Textos de creditos y agradecimientos incluidos en `frontend/assets/texts/`.

En caso de publicacion externa, debe revisarse la licencia y autoria de cada
asset grafico, modelo 3D, pista de audio, imagen o recurso derivado antes de
distribuir la aplicacion fuera del ambito academico.
