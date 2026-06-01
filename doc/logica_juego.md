# Logica del juego

El motor de reglas vive en `packages/lib/core/foundations_of_rome/`.
La app Flutter y el servidor lo importan desde `package:for_core/...`.

## Archivos principales

```text
packages/lib/core/foundations_of_rome/
  foundations_of_rome.dart       # Barrel export publico.
  building_catalog.dart          # Catalogo de edificios, monumentos y costes.
  entities/building.dart
  entities/deed_card.dart
  entities/player.dart
  entities/property.dart
  errors/game_error.dart
  errors/rule_error.dart
  game.dart                      # Estado y reglas de partida.
  value_objects/*.dart
```

## Entidades

- `Juego`: estado completo de una partida.
- `Jugador`: jugador, monedas, gloria, poblacion, solares y edificios disponibles.
- `Edificio`: plantilla de edificio o monumento.
- `Propiedad`: edificio construido en el tablero.
- `CartaEscritura`: carta/parcela del mercado.
- `Era`: era I, II o III.
- `TipoEdificio`: residencial, comercial o civico.
- `TipoJugador`: humano o bot.

## Estado dentro de `Juego`

Campos importantes:

- `players`: lista de jugadores.
- `indiceJugadorActual`: turno actual.
- `eraActual`: era actual.
- `propietariosLotes`: propietario de cada parcela.
- `edificios`: mapa de coordenada a `Propiedad`.
- `mazos`: mazos por era.
- `mercado`: cartas disponibles para comprar.
- `monumentosDisponibles`: monumentos comunes disponibles.
- `partidaFinalizada`: marca de final de partida.
- resumen pendiente: titulo, lineas, final/avance de era.

## Acciones principales

### Comprar parcela

Metodo: `Juego.comprarParcela(index)`

Flujo:

1. Comprueba que la partida no haya terminado.
2. Comprueba indice de mercado.
3. Calcula coste desde `costes`.
4. Comprueba monedas.
5. Transfiere carta del mercado al jugador.
6. Actualiza `propietariosLotes`, monedas y marcadores.
7. Rellena mercado.
8. Avanza turno.

### Construir

Metodos principales:

- `Juego.validarConstruccion(...)`
- `Juego.construir(...)`

Flujo:

1. Calcula la huella del edificio segun coordenada origen y rotacion.
2. Comprueba que las coordenadas esten en tablero.
3. Comprueba propiedad de parcelas.
4. Comprueba colisiones y reglas de reemplazo.
5. Si es monumento, valida requisitos especificos.
6. Elimina edificios reemplazados cuando aplica.
7. Crea una `Propiedad` compartida para todas las coordenadas ocupadas.
8. Actualiza bandejas, marcadores, poblacion y beneficios inmediatos.
9. Avanza turno.

### Recaudar ingresos

Metodo: `Juego.accionIngresos()`

Flujo:

1. Calcula ingreso base.
2. Suma beneficios comerciales y de monumentos segun estado.
3. Suma monedas al jugador.
4. Avanza turno.

## Eras y fin de partida

El juego usa `Era.I`, `Era.II` y `Era.III`.

Cuando corresponde puntuar:

```text
Juego
  -> calcula mayorias/puntuacion de era
  -> registra resumen pendiente
  -> si era III, ejecuta puntuacion final
```

La UI consume el resumen con `consumirResumenPendiente()` y confirma el avance de era con `confirmarResumenPendiente()`.

## Serializacion

`Juego.toJson()` serializa:

- jugadores
- turno
- era
- `propietariosLotes`
- `edificios`
- `mazos`
- `mercado`
- monumentos disponibles
- resumen pendiente si se solicita

`Juego.fromJson()` reconstruye una partida y normaliza edificios compartidos para que las coordenadas de una misma construccion apunten al mismo objeto `Propiedad`.

## Bots locales

Los bots estan en `application/bots/`.

Clases:

- `FoundationsOfRomeBotService`: decide la mejor accion simple.
- `BotPlannedAction`: representa build, buyDeed o income.
- `LocalBotTurnRunner`: ejecuta turnos bot consecutivos en partidas locales.

Prioridad actual del bot:

1. Construir edificio normal si hay opcion valida.
2. Construir monumento si hay opcion valida.
3. Comprar parcela si puede.
4. Recaudar ingresos.

## Donde tocar reglas

- Nueva regla de construccion: `validarConstruccion`, `_resolveBuildValidation` o helpers cercanos.
- Nuevo beneficio de edificio: metodos de ingresos/puntuacion/beneficios.
- Nuevo monumento: `building_catalog.dart` y validacion en `game.dart`.
- Cambio de serializacion: `toJson` y `fromJson`.
- Cambio de bot: `application/bots/foundations_of_rome_bot_service.dart`.
