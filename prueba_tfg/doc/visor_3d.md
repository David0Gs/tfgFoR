# Visor 3D

El visor vive en `lib/visor_3d/` y encapsula el render Three.js usado por Flutter.

## Estructura

```text
visor_3d/
  visor_3d_widget.dart
  interfaz_controlador.dart
  factory_plataforma.dart
  camara_config.dart
  escena/
    escena_threejs.dart
  plataformas/
    desktop/
      visor_desktop.dart
    web/
      inicializador_stub.dart
      inicializador_web.dart
      visor_web_controlador.dart
      visor_web_widget.dart
```

## Objetivo

Ofrecer una API comun a Flutter para:

- cargar tablero y modelos GLB.
- mover camara.
- resaltar/seleccionar casillas.
- renderizar edificios y miniaturas.
- recibir clicks desde la escena.

## Flujo

```text
PantallaTablero
  -> Visor3D
  -> Visor3DFactory
  -> WebViewerWidget o DesktopViewerWidget
  -> buildThreeJsHtml()
  -> Three.js
```

## Contrato de controlador

Archivo: `interfaz_controlador.dart`

`I3DViewerController` define las operaciones que la UI puede pedir al visor. Las implementaciones concretas dependen de la plataforma:

- Desktop: `visor_3d/plataformas/desktop/visor_desktop.dart`
- Web: `visor_3d/plataformas/web/visor_web_controlador.dart`

## Factory de plataforma

Archivo: `factory_plataforma.dart`

Elige widget/controlador segun `kIsWeb`.

Tambien usa import condicional para inicializacion web:

```dart
import 'plataformas/web/inicializador_stub.dart'
    if (dart.library.html) 'plataformas/web/inicializador_web.dart';
```

El stub es obligatorio para compilar fuera de web.

## Escena Three.js

Archivo: `escena/escena_threejs.dart`

Genera un documento HTML completo con JavaScript embebido. Este HTML se usa tanto en web como en escritorio.

Responsabilidades:

- configurar renderer, escena, camara y luces.
- cargar Three.js, OrbitControls, GLTFLoader y DRACOLoader.
- cargar modelos GLB.
- traducir coordenadas tablero <-> nombres de objetos.
- gestionar clicks.
- exponer funciones JS invocables desde Dart.

## Desktop

Archivo: `plataformas/desktop/visor_desktop.dart`

Usa `flutter_inappwebview`/WebView2. Carga el HTML generado y comunica Dart con JavaScript mediante el canal disponible en InAppWebView.

## Web

Archivos:

- `visor_web_widget.dart`
- `visor_web_controlador.dart`
- `inicializador_web.dart`

Usa `HtmlElementView` con iframe. `pointer_interceptor` en UI ayuda a que los overlays Flutter sigan recibiendo interacciones correctamente.

## Camara

Archivo: `camara_config.dart`

Centraliza valores por defecto:

- color de fondo.
- posicion/objetivo de camara.
- zoom minimo/maximo.
- angulos de orbit.

## Consejos de mantenimiento

- Cambios visuales globales del render: `escena_threejs.dart`.
- Cambios de camara: `camara_config.dart`.
- Nuevas operaciones desde Flutter: modificar `I3DViewerController` y ambas implementaciones.
- Problemas solo en web: revisar `plataformas/web/`.
- Problemas solo en Windows/escritorio: revisar `plataformas/desktop/`.
