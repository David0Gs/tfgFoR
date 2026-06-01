# Interfaz Flutter

La capa visual vive en `lib/presentation/`.

```text
presentation/
  screens/
    pantalla_menu_principal.dart
    pantalla_tablero.dart
  widgets/
    board_toolbar.dart
    building_catalog_overlay.dart
    contenido_dialog.dart
    creditos_panel.dart
    deed_market_bar.dart
    era_status_badge.dart
    mensaje_tablero_content.dart
    miniatura_edificio_3d.dart
    placement_hint_bar.dart
    player_info_card.dart
    player_stats_dialog.dart
    player_stat.dart
    players_hud.dart
    remote_join_dialog.dart
    remote_leaderboard_dialog.dart
    remote_participants_alert.dart
    resumen_partida_dialog.dart
    seleccion_anclaje_overlay.dart
    seleccion_jugadores_local.dart
    toolbar_icon_button.dart
```

## Pantalla de menu

Archivo: `presentation/screens/pantalla_menu_principal.dart`

Responsabilidades:

- Mostrar opciones principales.
- Reproducir audio al entrar.
- Abrir enlaces externos mediante `url_launcher`.
- Lanzar flujos de partida local/remota/ranking/instrucciones.
- Mostrar un dialogo de instrucciones simplificadas con enlaces al manual y al
  videotutorial del juego fisico original.

No contiene reglas de juego.

## Seleccion de jugadores locales

Archivo: `presentation/widgets/seleccion_jugadores_local.dart`

Responsabilidades:

- Elegir de 2 a 5 jugadores.
- Marcar cada jugador como humano o bot.
- Construir `LocalGameConfiguration`.
- Garantizar configuracion valida antes de iniciar.

## Pantalla de tablero

Archivo: `presentation/screens/pantalla_tablero.dart`

Es la pantalla principal durante una partida. Coordina:

- HUD de jugadores.
- Mercado.
- Bandeja de edificios.
- Monumentos disponibles.
- Dialogos de resumen.
- Guardado/carga en web.
- Estado remoto.
- Turnos bot.
- Visor 3D.

Dependencias principales:

- `Juego`: estado y reglas.
- `TableroController`: puente con el visor.
- `Visor3D`: widget 3D.
- `LocalBotTurnRunner`: turnos bot.
- `SesionRemotaController`: modo remoto.
- `AudioService`: musica.
- `persistencia_partida`: carga/descarga JSON.

`TableroController` tambien mantiene sincronizada la capa interactiva del visor:
los edificios construidos tienen colliders invisibles por casilla ocupada para
que la seleccion y sustitucion no dependan del raycast contra la geometria
completa de cada modelo GLB.

## Estado local de UI

`PantallaTablero` mantiene estado transitorio que no pertenece al dominio:

- seleccion actual de parcela/edificio/rotacion.
- flags de dialogos.
- mensajes visuales.
- estado de conexion remota.
- referencias al controlador 3D.

El estado persistible debe vivir en `Juego`, no en la pantalla.

## Layout movil del tablero

En Android/iOS, `PantallaTablero` fuerza orientacion horizontal mientras la
partida esta abierta. Al salir del tablero vuelve a liberar las orientaciones
del dispositivo.

El layout movil usa variantes compactas de varios widgets para evitar que se
pisen sobre pantallas pequenas:

- `DeedMarketBar`: botones mas bajos y etiquetas abreviadas, por ejemplo
  `A1 · 2`.
- `EraStatusBadge`: menos padding y texto mas pequeno.
- `PlayersHud`: columna inferior izquierda de chips de jugador con nombre,
  color y borde de turno activo.
- `PlayerInfoCard`: en modo compacto muestra nombre/color/resalto y vuelve a
  desplegar las estadisticas del jugador que tiene el turno.
- `BoardToolbar`: botones mas pequenos y un boton tactil de rotacion de
  edificio. Durante la colocacion en movil tambien muestra un boton `X` para
  cancelar la preview, equivalente al click derecho de escritorio.

En movil, tocar cualquier jugador abre directamente `PlayerStatsDialog`. Esto
sustituye al panel desplegado de escritorio y ahorra espacio en el HUD.

La rotacion de edificios en escritorio sigue funcionando con la rueda del
raton. En movil se usa el boton de rotacion de `BoardToolbar`; cada toque avanza
una rotacion de 90 grados cuando el edificio lo permite.

## Miniaturas 3D

Archivo: `presentation/widgets/miniatura_edificio_3d.dart`

Muestra la miniatura visual de cada edificio dentro del catalogo.

En escritorio puede reproducir el video `.mp4` de miniatura, con una cache
limitada de controladores para evitar abrir demasiados reproductores a la vez.

En Android/iOS no se inicializan videos: se muestra solo el poster `.webp`
correspondiente desde `assets/thumbnails/posters/`. Esto evita crear
decodificadores nativos durante el scroll de la bandeja y reduce tirones en
moviles.

## Widgets reutilizables extraidos

Ademas de la seleccion de jugadores y las miniaturas 3D, hay widgets pequenos que antes vivian dentro de pantallas grandes:

- `board_toolbar.dart`: barra vertical de acciones del tablero.
- `building_catalog_overlay.dart`: catalogo de construccion de edificios y monumentos.
- `contenido_dialog.dart`: marco modal reutilizable para textos del menu; lo usan
  instrucciones y agradecimientos.
- `creditos_panel.dart`: panel desplazable y autoformateado para agradecimientos
  y creditos.
- `deed_market_bar.dart`: mercado superior de parcelas.
- `era_status_badge.dart`: indicador de era y cartas restantes.
- `mensaje_tablero_content.dart`: contenido de mensajes/snackbars del tablero.
- `placement_hint_bar.dart`: ayuda visual durante la colocacion de edificios.
- `player_info_card.dart`: tarjeta resumida de jugador en el HUD.
- `player_stats_dialog.dart`: dialogo de estadisticas detalladas de un jugador.
- `player_stat.dart`: linea de estadistica reutilizada en tarjetas y dialogos.
- `players_hud.dart`: panel de tarjetas de jugadores.
- `remote_join_dialog.dart`: dialogo para introducir URL y alias de partida remota.
- `remote_leaderboard_dialog.dart`: dialogo de ranking remoto.
- `remote_participants_alert.dart`: aviso de participantes remotos desconectados.
- `resumen_partida_dialog.dart`: dialogo de resumen de era o final de partida.
- `seleccion_anclaje_overlay.dart`: overlay para elegir la parcela origen cuando un edificio ocupa varias.
- `toolbar_icon_button.dart`: boton de icono de la barra de herramientas del tablero.

Estos widgets no contienen reglas de juego. Reciben datos y callbacks desde las pantallas.

## Pautas de UI

- La UI debe llamar a metodos de `Juego`, no duplicar reglas.
- Si una comprobacion afecta reglas, debe vivir en dominio.
- Si una comprobacion solo afecta habilitar/deshabilitar botones, puede vivir en presentation.
- Mantener widgets reutilizables en `presentation/widgets/`.
- Mantener pantallas completas en `presentation/screens/`.
