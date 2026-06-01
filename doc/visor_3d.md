# Visor 3D

El visor vive en `lib/visor_3d/` y encapsula el render Three.js usado por Flutter.

## Estructura

```text
visor_3d/
  visor_3d_widget.dart
  interfaz_controlador.dart
  factory_plataforma.dart
  camara_config.dart
  escena_threejs.dart
  plataformas/
    visor_desktop.dart
    visor_mobile.dart
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
  -> WebViewerWidget, DesktopViewerWidget o MobileViewerWidget
  -> buildThreeJsHtml()
  -> Three.js
```

## Contrato de controlador

Archivo: `interfaz_controlador.dart`

`I3DViewerController` define las operaciones que la UI puede pedir al visor. Las implementaciones concretas dependen de la plataforma:

- Desktop: `visor_3d/plataformas/visor_desktop.dart`
- Mobile: `visor_3d/plataformas/visor_mobile.dart`
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

Archivo: `escena_threejs.dart`

Genera un documento HTML completo con JavaScript embebido. Este HTML se usa tanto en web como en escritorio.

Responsabilidades:

- configurar renderer, escena, camara y luces.
- cargar Three.js, OrbitControls, GLTFLoader y DRACOLoader.
- cargar modelos GLB.
- mantener una cache de GLB por URL y liberar geometria, materiales y texturas
  cuando un GLB deja de tener instancias en escena.
- traducir coordenadas tablero <-> nombres de objetos.
- gestionar clicks. Los edificios construidos usan colliders invisibles
  simples, sincronizados con sus casillas ocupadas, para evitar raycast sobre
  toda la geometria del GLB.
- exponer funciones JS invocables desde Dart.
- renderizar bajo demanda: el visor no dibuja continuamente salvo cuando hay
  animaciones, cambios de camara o cambios visuales que solicitan un frame.

## Clicks y colliders

El tablero y los marcadores siguen siendo objetos clicables directamente. En
los edificios construidos, `TableroController` llama a
`syncBuildingClickColliders()` con las coordenadas ocupadas por la propiedad.
Three.js crea una caja invisible por casilla y registra esas cajas en el
raycast. El modelo visual queda fuera del raycast, pero el click devuelve el
mismo `buildingId`.

Esto mantiene la jugabilidad de seleccion/sustitucion de edificios y reduce el
coste de interaccion cuando hay muchos modelos complejos en escena.

## Desktop

Archivo: `plataformas/visor_desktop.dart`

Usa `flutter_inappwebview`/WebView2. Carga el HTML generado y comunica Dart con JavaScript mediante el canal disponible en InAppWebView.

## Mobile

Archivo: `plataformas/visor_mobile.dart`

Usa `flutter_inappwebview` con un servidor HTTP local en `127.0.0.1` para
servir el HTML de Three.js y los assets incluidos en Flutter. Esto evita
depender de un servidor externo para cargar tablero, escenario y edificios.

En Android, ese servidor local usa `http://127.0.0.1:<puerto>`. Por eso el
manifest principal incluye `android:usesCleartextTraffic="true"` en
`<application>`. Sin ese ajuste, el WebView muestra `ERR_CLEARTEXT_NOT_PERMITTED`
y el tablero 3D no llega a cargar.

La version movil usa ajustes especificos para reducir consumo:

- `lowPowerMode` en la escena Three.js.
- limite de `pixelRatio` mas bajo que escritorio/web.
- fondo panoramico ligero `fondo_mobile.webp` en lugar del HDRI completo como
  fondo visual.
- cabeceras de cache en el servidor local de assets.
- poda de la cache interna de modelos GLB cuando los modelos ya no estan en
  escena. La limpieza libera tambien geometria, materiales y texturas del GLB
  base, no solo la referencia del mapa.
- miniaturas de edificios en la bandeja como posters `.webp`; en movil no se
  inicializan videos para evitar decodificadores nativos durante el scroll.

La configuracion de ventana con `window_manager` solo debe ejecutarse en
escritorio. Android no implementa ese plugin; si se llama desde movil aparece
`MissingPluginException`.

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
- Problemas solo en Windows/escritorio: revisar `plataformas/visor_desktop.dart`.
- Problemas solo en Android/movil: revisar `plataformas/visor_mobile.dart`,
  `android/app/src/main/AndroidManifest.xml` y que no se ejecuten llamadas a
  `window_manager`.
