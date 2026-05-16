# Flujo de datos

La fuente principal de verdad de una partida es `Game`. La UI no replica las reglas: pide acciones al motor y despues refresca su estado visual desde el estado resultante.

## Arranque de la aplicacion

```text
bin/main.dart
  -> ApplicationConfig.inicializar()
     -> registra plataforma WebView/ventana
     -> inicializa AudioService
  -> runApp()
  -> PantallaMenuPrincipal
```

Desde el menu se puede iniciar:

- partida local
- conexion remota
- ranking/manual/video/enlaces externos

## Partida local

```text
PantallaMenuPrincipal
  -> SeleccionJugadoresLocal
  -> LocalGameConfiguration
  -> Game(playerCount, playerKinds)
  -> PantallaTablero
```

En `PantallaTablero`:

```text
Usuario pulsa una accion
  -> PantallaTablero valida el contexto de UI
  -> Game.actionBuyDeed / Game.actionBuild / Game.actionIncome
  -> Game muta estado y registra resumen si aplica
  -> PantallaTablero sincroniza visor 3D y HUD
  -> LocalBotTurnRunner ejecuta bots si el siguiente turno es bot
```

El estado que se visualiza sale de:

- `game.players`
- `game.market`
- `game.availableMonuments`
- `game.buildings`
- `game.pendingSummary`

## Partida remota

```text
PantallaMenuPrincipal
  -> dialogo de conexion
  -> SesionRemotaController.connect()
  -> WebSocket
  -> servidor headless
```

El cliente remoto no debe inventar estado. El servidor aplica acciones sobre su propia instancia de `Game` y difunde snapshots.

```text
Cliente envia action
  -> Servidor valida turno y payload
  -> Servidor llama a Game
  -> Servidor emite snapshot/eraSummary/presence
  -> SesionRemotaController actualiza estado
  -> PantallaTablero reconstruye UI
```

## Guardado y carga

La serializacion vive en el dominio:

```text
Game.toJson()
Game.fromJson()
Game.toJsonString()
Game.fromJsonString()
```

La infraestructura decide como mover ese JSON:

```text
Web:
  persistencia_partida_web.dart
    -> descarga archivo JSON
    -> carga archivo JSON desde input del navegador

No web:
  persistencia_partida_stub.dart
    -> lanza UnsupportedError
```

## Visor 3D

El flujo hacia el visor es unidireccional para renderizar y bidireccional para clicks:

```text
PantallaTablero
  -> TableroController
  -> I3DViewerController
  -> WebViewerWidget / DesktopViewerWidget
  -> Three.js

Click en Three.js
  -> controlador de plataforma
  -> TableroController
  -> PantallaTablero
  -> accion de usuario o seleccion
```

## Resumen de dependencias de estado

```text
Game
  -> estado de reglas
  -> serializacion
  -> resumen de era/final

PantallaTablero
  -> estado transitorio de UI
  -> seleccion actual
  -> dialogos
  -> sincronizacion con visor

SesionRemotaController
  -> estado remoto recibido
  -> presencia
  -> errores de red/protocolo

TableroController
  -> comandos visuales hacia Three.js
```
