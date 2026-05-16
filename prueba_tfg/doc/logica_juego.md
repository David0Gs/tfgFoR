# Logica del juego

El motor de reglas vive en `lib/domain/foundations_of_rome/` y debe importarse directamente desde `domain/foundations_of_rome/foundations_of_rome.dart`.

## Archivos principales

```text
domain/foundations_of_rome/
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

- `Game`: estado completo de una partida.
- `Player`: jugador, monedas, gloria, poblacion, solares y edificios disponibles.
- `Building`: plantilla de edificio o monumento.
- `Property`: edificio construido en el tablero.
- `DeedCard`: carta/parcela del mercado.
- `Era`: era I, II o III.
- `BuildingType`: residencial, comercial o civico.
- `PlayerKind`: humano o bot.

## Estado dentro de `Game`

Campos importantes:

- `players`: lista de jugadores.
- `currentPlayerIndex`: turno actual.
- `currentEra`: era actual.
- `lotOwner`: propietario de cada parcela.
- `buildings`: mapa de coordenada a `Property`.
- `decks`: mazos por era.
- `market`: cartas disponibles para comprar.
- `availableMonuments`: monumentos comunes disponibles.
- `gameFinished`: marca de final de partida.
- resumen pendiente: titulo, lineas, final/avance de era.

## Acciones principales

### Comprar parcela

Metodo: `Game.actionBuyDeed(index)`

Flujo:

1. Comprueba que la partida no haya terminado.
2. Comprueba indice de mercado.
3. Calcula coste desde `costs`.
4. Comprueba monedas.
5. Transfiere carta del mercado al jugador.
6. Actualiza `lotOwner`, monedas y marcadores.
7. Rellena mercado.
8. Avanza turno.

### Construir

Metodos principales:

- `Game.validateBuild(...)`
- `Game.actionBuild(...)`

Flujo:

1. Calcula la huella del edificio segun coordenada origen y rotacion.
2. Comprueba que las coordenadas esten en tablero.
3. Comprueba propiedad de parcelas.
4. Comprueba colisiones y reglas de reemplazo.
5. Si es monumento, valida requisitos especificos.
6. Elimina edificios reemplazados cuando aplica.
7. Crea una `Property` compartida para todas las coordenadas ocupadas.
8. Actualiza bandejas, marcadores, poblacion y beneficios inmediatos.
9. Avanza turno.

### Recaudar ingresos

Metodo: `Game.actionIncome()`

Flujo:

1. Calcula ingreso base.
2. Suma beneficios comerciales y de monumentos segun estado.
3. Suma monedas al jugador.
4. Avanza turno.

## Eras y fin de partida

El juego usa `Era.I`, `Era.II` y `Era.III`.

Cuando corresponde puntuar:

```text
Game
  -> calcula mayorias/puntuacion de era
  -> registra resumen pendiente
  -> si era III, ejecuta puntuacion final
```

La UI consume el resumen con `consumePendingSummary()` y confirma el avance de era con `confirmPendingSummary()`.

## Serializacion

`Game.toJson()` serializa:

- jugadores
- turno
- era
- lotOwner
- buildings
- decks
- market
- monumentos disponibles
- resumen pendiente si se solicita

`Game.fromJson()` reconstruye una partida y normaliza edificios compartidos para que las coordenadas de una misma construccion apunten al mismo objeto `Property`.

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

- Nueva regla de construccion: `validateBuild` o helpers cercanos.
- Nuevo beneficio de edificio: metodos de ingresos/puntuacion/beneficios.
- Nuevo monumento: `building_catalog.dart` y validacion en `game.dart`.
- Cambio de serializacion: `toJson` y `fromJson`.
- Cambio de bot: `application/bots/foundations_of_rome_bot_service.dart`.
