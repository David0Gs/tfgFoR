# Flujo de datos

La fuente principal de verdad de una partida es `Juego`. La UI no replica las reglas: pide acciones al motor y despues refresca su estado visual desde el estado resultante.

## Arranque de la aplicacion

```text
lib/main.dart
  -> runFlutterApp()
  -> ApplicationConfig.inicializar()
     -> registra plataforma WebView/ventana
  -> runApp()
  -> PantallaMenuPrincipal
  -> inicializa AudioService tras el primer frame
```

Desde el menu se puede iniciar:

- partida local
- conexion remota
- ranking
- instrucciones resumidas con enlaces al manual y videotutorial originales
- agradecimientos y creditos
- salir de la aplicacion en plataformas no web

## Partida local

```text
PantallaMenuPrincipal
  -> SeleccionJugadoresLocal
  -> LocalGameConfiguration
  -> Juego(numeroJugadores, playerKinds)
  -> PantallaTablero
```

En `PantallaTablero`:

```text
Usuario pulsa una accion
  -> PantallaTablero valida el contexto de UI
  -> Juego.comprarParcela / Juego.construir / Juego.accionIngresos
  -> Juego muta estado y registra resumen si aplica
  -> PantallaTablero sincroniza visor 3D y HUD
  -> LocalBotTurnRunner ejecuta bots si el siguiente turno es bot
```

El estado que se visualiza sale de:

- `game.players`
- `game.mercado`
- `game.monumentosDisponibles`
- `game.edificios`
- resumen pendiente consumido con `game.consumirResumenPendiente()`

## Partida remota

```text
PantallaMenuPrincipal
  -> dialogo de conexion
  -> SesionRemotaController.unirse()
  -> WebSocket
  -> servidor Dart en backend/
```

El cliente remoto no debe inventar estado. El servidor aplica acciones sobre su propia instancia de `Juego` y difunde snapshots.

```text
Cliente envia action
  -> Servidor valida turno y payload
  -> Servidor llama a Juego
  -> Servidor emite snapshot/eraSummary/presence
  -> SesionRemotaController actualiza estado
  -> PantallaTablero reconstruye UI
```

## Guardado y carga

La serializacion vive en el dominio:

```text
Juego.toJson()
Juego.fromJson()
Juego.toJsonString()
Juego.fromJsonString()
```

La infraestructura decide como mover ese JSON:

```text
Web:
  persistencia_partida_web.dart
    -> descarga archivo JSON
    -> carga archivo JSON desde input del navegador

No web:
  persistencia_partida_stub.dart
    -> guarda/carga `partida_guardada.json` en Documents/Foundations of Rome
    -> si no encuentra archivo, devuelve null
```

## Visor 3D

El flujo hacia el visor es unidireccional para renderizar y bidireccional para clicks:

```text
PantallaTablero
  -> TableroController
  -> I3DViewerController
  -> WebViewerWidget, DesktopViewerWidget o MobileViewerWidget
  -> Three.js

Click en Three.js
  -> controlador de plataforma
  -> TableroController
  -> PantallaTablero
  -> accion de usuario o seleccion
```

## Resumen de dependencias de estado

```text
Juego
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
