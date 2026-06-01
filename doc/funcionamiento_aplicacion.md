# Funcionamiento de la aplicacion explicado paso a paso

Este documento explica que ocurre en la aplicacion desde que se abre hasta que termina una partida. Esta escrito para una persona con pocos conocimientos de informatica, asi que evita tecnicismos siempre que sea posible.

La idea principal es esta: la aplicacion muestra pantallas con Flutter, guarda las reglas del juego en una clase llamada `Juego`, y usa un visor 3D para que el tablero, los marcadores y los edificios se vean como piezas sobre la mesa.

## 1. Arranque de la aplicacion

El primer archivo importante es `lib/main.dart`.

Ese archivo hace muy poco:

```dart
Future<void> main() async {
  await runFlutterApp();
}
```

Es decir, cuando se abre la aplicacion, se llama a `runFlutterApp()`, que esta en `lib/app_entrypoint.dart`.

Dentro de `runFlutterApp()` pasan estas cosas:

1. Se inicializa la configuracion general con `ApplicationConfig.inicializar()`.
2. Se crea la aplicacion Flutter con `runApp(...)`.
3. Se muestra como primera pantalla `PantallaMenuPrincipal`.
4. Despues del primer dibujo de pantalla, se inicializa el audio de fondo.

`ApplicationConfig.inicializar()` prepara detalles de plataforma:

- En escritorio configura la ventana.
- En web desactiva el menu contextual del navegador.
- Registra soporte para video y visor web cuando hace falta.
- Prepara la aplicacion para que el audio pueda arrancar tras una interaccion del usuario.

## 2. Menu principal

La primera pantalla visible es `PantallaMenuPrincipal`, en `lib/presentation/screens/pantalla_menu_principal.dart`.

Esta pantalla no contiene reglas del juego. Solo ofrece opciones:

- Iniciar partida local.
- Cargar partida.
- Conectar a partida remota.
- Ver ranking.
- Abrir instrucciones resumidas.
- Ver agradecimientos y creditos.
- Salir de la aplicacion en plataformas no web.

El boton de instrucciones abre una ventana con las reglas simplificadas de esta
version digital. Desde esa misma ventana se puede abrir tambien el manual de
reglas y el videotutorial del juego fisico original, que tienen una jugabilidad
mas amplia que la implementada aqui.

Cuando la persona pulsa una opcion, el menu llama a funciones definidas en `app_entrypoint.dart`.

Por ejemplo:

- Si pulsa iniciar partida local, se llama a `_abrirPartidaLocal`.
- Si pulsa cargar partida, se llama a `_abrirPartidaGuardada`.
- Si pulsa conectar a partida remota, se llama a `_abrirPartidaRemota`.

## 3. Elegir jugadores en partida local

Si se inicia una partida local, aparece un dialogo de seleccion de jugadores.

Ese dialogo esta en `lib/presentation/widgets/seleccion_jugadores_local.dart`.

Aqui se decide:

- Cuantos jugadores habra, de 2 a 5.
- Si cada jugador sera humano o bot.

El resultado se guarda en un objeto llamado `LocalGameConfiguration`. Ese objeto solo describe la configuracion inicial: numero de jugadores y tipo de cada jugador.

Cuando se confirma, la aplicacion abandona el menu y abre `PantallaTablero`.

## 4. Creacion de la partida

La pantalla de tablero esta en `lib/presentation/screens/pantalla_tablero.dart`.

Al abrirse, en `initState()`, la pantalla decide si ya tiene una partida cargada o si debe crear una nueva:

```dart
_game = widget.initialGame ?? Juego(...);
```

Si venimos de cargar una partida, `initialGame` ya contiene el estado recuperado desde un archivo JSON.

Si empezamos una partida nueva, se crea un objeto `Juego`.

`Juego` es la pieza central del proyecto. Vive en `packages/lib/core/foundations_of_rome/game.dart` y contiene:

- Los jugadores.
- De quien es el turno.
- La era actual.
- El tamano del tablero.
- Que parcelas pertenecen a cada jugador.
- Que edificios hay construidos.
- Las cartas de parcela que quedan en los mazos.
- Las cartas visibles en el mercado.
- Los monumentos disponibles.
- Si la partida ya ha terminado.

Cuando se crea `Juego`, su constructor prepara la partida:

1. Decide el tamano del tablero:
   - 2 jugadores: tablero 7x7.
   - 3 jugadores: tablero 8x8.
   - 4 jugadores: tablero 9x9.
   - 5 jugadores: tablero 10x10.
2. Crea los jugadores.
3. Da a cada jugador sus edificios disponibles.
4. Selecciona monumentos aleatorios.
5. Crea los mazos de parcelas de las eras I, II y III.
6. Rellena el mercado inicial con hasta 6 cartas de parcela.

## 5. Carga del tablero 3D

Aunque `Juego` sabe las reglas, no dibuja nada.

Para mostrar el tablero se usa:

- `Visor3D`, en `lib/visor_3d/visor_3d_widget.dart`.
- `TableroController`, en `lib/controlador_tablero.dart`.

El visor 3D se encarga de mostrar modelos `.glb`, como el tablero, los marcadores y los edificios.

El controlador del tablero actua como puente entre el juego y la escena 3D. Por ejemplo:

- Si una parcela se compra, coloca un marcador sobre esa casilla.
- Si un edificio se construye, carga su modelo 3D.
- Si un edificio se retira o se sustituye, lo elimina o actualiza.
- Si la persona pulsa una pieza del tablero, informa a la pantalla.

Cuando el modelo del tablero termina de cargar, `PantallaTablero` marca `_tablero3DListo = true` y sincroniza la escena 3D con el estado de `Juego`.

## 6. Que ve el jugador durante la partida

En `PantallaTablero` se muestran varias zonas de informacion:

- El tablero 3D.
- El jugador actual.
- Monedas, gloria, poblacion y marcadores.
- El mercado de parcelas.
- La lista de edificios disponibles.
- Los monumentos disponibles.
- Botones para cobrar ingresos, guardar partida o salir.

La pantalla guarda tambien informacion temporal de interfaz, por ejemplo:

- Que parcela esta seleccionada.
- Que edificio se esta intentando colocar.
- Que rotacion tiene el edificio.
- Si se esta mostrando el catalogo de edificios.
- Si hay un resumen de era abierto.

Esa informacion temporal no es la partida en si. La partida real esta en `Juego`.

La parte visual del tablero esta modularizada en widgets reutilizables dentro de `lib/presentation/widgets/`. Algunos ejemplos:

- `players_hud.dart`: muestra las tarjetas de jugadores.
- `deed_market_bar.dart`: muestra el mercado de parcelas.
- `building_catalog_overlay.dart`: muestra el catalogo para construir.
- `board_toolbar.dart`: muestra los botones de audio, camara, cobrar, guardar y salir.
- `resumen_partida_dialog.dart`: muestra los resumenes de era y final.

Estos widgets no deciden reglas. Solo reciben datos y callbacks desde `PantallaTablero`.

## 7. Acciones de un turno

En cada turno, el jugador puede hacer una accion principal. Las tres acciones mas importantes son:

- Cobrar ingresos.
- Comprar una parcela.
- Construir un edificio o monumento.

### Cobrar ingresos

Cuando se pulsa el boton de ingresos, `PantallaTablero` llama a `_ejecutarIngreso()`.

Si la partida es local, esa funcion llama a:

```dart
_game.accionIngresos();
```

Dentro de `Juego`, `accionIngresos()`:

1. Comprueba que la partida no haya terminado.
2. Toma al jugador actual.
3. Le da una base de 5 monedas.
4. Suma monedas extra por edificios comerciales.
5. Suma posibles bonus de monumentos.
6. Anade esas monedas al jugador.
7. Termina el turno llamando a `_endTurn()`.

Despues, la pantalla actualiza el mercado, el tablero 3D y comprueba si hay que mostrar resumen de era o ejecutar bots.

### Comprar una parcela

El mercado muestra cartas de parcela, por ejemplo `A1`, `C4` o `F7`.

Cada posicion del mercado tiene un coste. Cuando la persona pulsa una carta, la pantalla llama a:

```dart
_game.comprarParcela(index);
```

Dentro de `Juego`, `comprarParcela()`:

1. Comprueba que la partida sigue activa.
2. Comprueba que el indice del mercado es valido.
3. Comprueba que el jugador tiene marcadores libres.
4. Comprueba que tiene monedas suficientes.
5. Resta el coste.
6. Saca la carta del mercado.
7. Anade esa parcela a la lista de parcelas del jugador.
8. Coloca el propietario de esa coordenada en `propietariosLotes`.
9. Consume un marcador del jugador.
10. Rellena el mercado con otra carta si quedan cartas.
11. Termina el turno con `_endTurn()`.

Visualmente, `TableroController` coloca un marcador 3D en la parcela comprada.

### Construir un edificio

Construir tiene mas pasos porque hay que elegir parcela, edificio y rotacion.

El flujo normal es:

1. La persona pulsa una parcela propia en el tablero.
2. La pantalla comprueba que esa parcela pertenece al jugador actual.
3. Se abre el catalogo de edificios y monumentos colocables.
4. La persona elige un edificio.
5. Aparece una previsualizacion 3D sobre el tablero.
6. La persona puede rotar la pieza.
7. Al confirmar, la pantalla llama a `Juego.validarConstruccion(...)`.
8. Si todo es correcto, se llama a `Juego.construir(...)`.

La validacion de construccion comprueba cosas como:

- Que la partida no haya terminado.
- Que la coordenada exista en el tablero.
- Que la parcela de origen sea del jugador.
- Que todas las casillas que ocupara el edificio sean del jugador.
- Que la rotacion no saque el edificio fuera del tablero.
- Que el edificio seleccionado siga disponible.
- Que el monumento cumpla sus requisitos.
- Que si se sustituye un edificio, el nuevo ocupe mas parcelas que el anterior.

Si algo falla, `Juego` lanza un `RuleError` con un mensaje. La pantalla lo muestra como aviso.

Si todo va bien, `construir()`:

1. Retira edificios antiguos si se esta sustituyendo alguno.
2. Crea una `Propiedad`, que representa el edificio ya colocado.
3. Marca todas sus coordenadas como ocupadas por ese edificio.
4. Devuelve marcadores al jugador por las parcelas que ya no necesitan marcador.
5. Quita el edificio de la bandeja del jugador o el monumento de la bandeja comun.
6. Recalcula la poblacion.
7. Aplica beneficios inmediatos si es un monumento.
8. Termina el turno con `_endTurn()`.

Despues, `TableroController` cambia la previsualizacion por el edificio definitivo en 3D.

## 8. Como avanzan los turnos

El avance de turno esta concentrado en `_endTurn()`, dentro de `Juego`.

Cada vez que una accion termina, se cambia el indice del jugador actual:

```dart
indiceJugadorActual = (indiceJugadorActual + 1) % numeroJugadores;
```

Eso significa:

- Si estaba jugando el jugador 1, pasa al 2.
- Si estaba jugando el ultimo jugador, vuelve al primero.

Despues de cambiar el turno, `_endTurn()` comprueba si se ha agotado el mercado y el mazo de la era actual.

Si se han agotado:

- En era I o II, se puntua la era y se prepara el avance a la siguiente.
- En era III, se activa primero una ronda final adicional.
- Cuando termina esa ronda final de era III, se hace la puntuacion final.

## 9. Bots locales

Si un jugador es bot, la pantalla no espera a que una persona actue.

`PantallaTablero` llama a `LocalBotTurnRunner`, que esta en `lib/application/bots/local_bot_turn_runner.dart`.

El bot usa `FoundationsOfRomeBotService` para decidir.

Su prioridad actual es:

1. Construir un edificio normal si puede.
2. Construir un monumento si puede.
3. Comprar una parcela si tiene monedas y marcadores.
4. Cobrar ingresos si no puede hacer nada mejor.

Cuando un bot hace una accion, se usan los mismos metodos de `Juego` que usa una persona. Esto es importante: las reglas no estan duplicadas para los bots.

## 10. Puntuacion de eras

La puntuacion esta en `_scoreEra()`, dentro de `Juego`.

Cuando se acaba una era, la partida calcula puntos para cada jugador:

- Puntos por poblacion.
- Puntos por edificios civicos.
- Puntos por monumentos.
- En era III, puntos extra de edificios comerciales.

En eras I y II, los edificios comerciales tambien pueden dar monedas.

El resultado no se muestra directamente desde `Juego`. En su lugar, `Juego` guarda un resumen pendiente con:

```dart
registrarResumenPendiente(...)
```

Luego `PantallaTablero` lo recoge con:

```dart
_game.consumirResumenPendiente();
```

Y lo enseña en un dialogo.

Cuando la persona confirma el dialogo, la pantalla llama a:

```dart
_game.confirmarResumenPendiente();
```

Si era una puntuacion de era I o II, ahi se avanza realmente a la siguiente era y se rellena de nuevo el mercado.

## 11. Final de partida

El final ocurre al agotarse la era III y completarse la ronda final.

Entonces `Juego` llama a `_finalScoring()`.

La puntuacion final hace esto:

1. Marca `partidaFinalizada = true`.
2. Da puntos por parcelas vacias que aun tenga cada jugador.
3. Ordena a los jugadores por puntos de gloria.
4. Crea el ranking final.
5. Decide si hay ganador unico o empate.
6. Registra un resumen final pendiente.

La pantalla muestra ese resumen final en un dialogo. A partir de ese momento, las interacciones de partida quedan bloqueadas porque `partidaFinalizada` ya es `true`.

## 12. Guardar y cargar partida

El guardado convierte el estado completo de `Juego` en texto JSON:

```dart
_game.toJsonString();
```

Ese JSON incluye jugadores, turno actual, era, parcelas, edificios, mazos, mercado, monumentos y estado de final de partida.

Para cargar, ocurre lo contrario:

```dart
Juego.fromJsonString(jsonString);
```

Asi se reconstruye la partida y se abre directamente `PantallaTablero` con ese estado.

En web, la persistencia usa `persistencia_partida_web.dart`: descarga un archivo JSON y permite seleccionar uno desde el navegador. En plataformas no web se usa `persistencia_partida_stub.dart`, que pese al nombre actual guarda y carga `partida_guardada.json` en una carpeta local de Documents.

## 13. Modo remoto resumido

La aplicacion tambien puede conectarse a una partida remota con `SesionRemotaController`.

En modo remoto, la pantalla sigue siendo la misma, pero cuando el jugador compra, construye o cobra ingresos, no modifica directamente `_game`. Envia la accion al servidor.

El servidor responde con un nuevo estado de partida. Entonces la pantalla aplica ese estado con `_aplicarJuego(...)` y vuelve a sincronizar el tablero 3D.

La idea es que el servidor sea quien mantiene la verdad de la partida remota, mientras que la aplicacion local se encarga de mostrarla y de enviar las acciones del usuario.

## 14. Resumen mental del flujo completo

Una forma sencilla de recordar el funcionamiento es esta:

```text
Se abre la app
  -> se prepara Flutter, audio y plataforma
  -> aparece el menu principal
  -> se elige partida local, cargada o remota
  -> se crea o recupera un objeto Juego
  -> se abre PantallaTablero
  -> se carga el tablero 3D
  -> el jugador hace una accion
  -> Juego valida y cambia el estado
  -> el tablero 3D se sincroniza con ese estado
  -> pasa el turno
  -> si toca bot, el bot actua
  -> si se agota una era, se puntua y se muestra resumen
  -> tras era III y ronda final, se calcula ranking final
  -> la partida queda finalizada
```

La separacion importante es:

- `PantallaTablero` pregunta y muestra.
- `Juego` decide si una accion es legal y cambia la partida.
- `TableroController` hace que el estado se vea en 3D.
- Los bots y el modo remoto tambien pasan por las reglas de `Juego`, directa o indirectamente.

Por eso, si se quiere entender o cambiar una regla, casi siempre hay que empezar en `packages/lib/core/foundations_of_rome/game.dart`. Si se quiere cambiar como se ve o como se pulsa algo, normalmente hay que mirar `lib/presentation/screens/pantalla_tablero.dart` o `lib/controlador_tablero.dart`.
