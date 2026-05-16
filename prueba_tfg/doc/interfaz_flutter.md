# Interfaz Flutter

La capa visual vive en `lib/presentation/`.

```text
presentation/
  screens/
    pantalla_menu_principal.dart
    pantalla_tablero.dart
  widgets/
    miniatura_edificio_3d.dart
    seleccion_jugadores_local.dart
```

## Pantalla de menu

Archivo: `presentation/screens/pantalla_menu_principal.dart`

Responsabilidades:

- Mostrar opciones principales.
- Reproducir audio al entrar.
- Abrir enlaces externos mediante `BrowserLauncher`.
- Lanzar flujos de partida local/remota/ranking/manual.

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

- `Game`: estado y reglas.
- `TableroController`: puente con el visor.
- `Visor3D`: widget 3D.
- `LocalBotTurnRunner`: turnos bot.
- `SesionRemotaController`: modo remoto.
- `AudioService`: musica.
- `persistencia_partida`: carga/descarga JSON.

## Estado local de UI

`PantallaTablero` mantiene estado transitorio que no pertenece al dominio:

- seleccion actual de parcela/edificio/rotacion.
- flags de dialogos.
- mensajes visuales.
- estado de conexion remota.
- referencias al controlador 3D.

El estado persistible debe vivir en `Game`, no en la pantalla.

## Miniaturas 3D

Archivo: `presentation/widgets/miniatura_edificio_3d.dart`

Usa la misma infraestructura de visor 3D para mostrar previews compactas de edificios.

## Pautas de UI

- La UI debe llamar a metodos de `Game`, no duplicar reglas.
- Si una comprobacion afecta reglas, debe vivir en dominio.
- Si una comprobacion solo afecta habilitar/deshabilitar botones, puede vivir en presentation.
- Mantener widgets reutilizables en `presentation/widgets/`.
- Mantener pantallas completas en `presentation/screens/`.
