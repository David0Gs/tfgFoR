# Documentacion tecnica de prueba_tfg

Este directorio contiene la documentacion de mantenimiento de la aplicacion. El objetivo es que una persona nueva pueda entender que hace cada capa, como fluye el estado y donde tocar cuando cambie una regla, una pantalla, el visor 3D o el modo remoto.

## Lectura recomendada

1. [Arquitectura](arquitectura.md)
2. [Flujo de datos](flujo_datos.md)
3. [Logica del juego](logica_juego.md)
4. [Interfaz Flutter](interfaz_flutter.md)
5. [Visor 3D](visor_3d.md)
6. [Persistencia, audio e infraestructura](infraestructura.md)
7. [Modo remoto y ranking](modo_remoto.md)
8. [Guia de mantenimiento](mantenimiento.md)

## Estado actual

`prueba_tfg` es una aplicacion Flutter multiplataforma para una adaptacion digital de Foundations of Rome. La aplicacion incluye:

- Partida local con jugadores humanos y bots.
- Partida remota por WebSocket.
- Motor de reglas compartido entre Flutter, CLI y servidor headless.
- Visor 3D con Three.js embebido en web y escritorio.
- Guardado/carga de partida en web.
- Ranking global persistido con SQLite en el servidor.
- Audio multiplataforma.

## Estructura principal

```text
lib/
  main.dart
  application/       # Coordinacion de casos de uso y servicios de aplicacion.
  domain/            # Modelo de negocio y reglas puras.
  infrastructure/    # Adaptadores externos: audio, red, SQLite, navegador, plataforma.
  presentation/      # Pantallas y widgets Flutter.
  visor_3d/          # Subsistema visual 3D y puentes por plataforma.
  juego/             # Fachadas/puentes heredados hacia tablero y modelos.
  FoR/               # Fachada historica y CLI.

bin/
  for_headless_server.dart

test/
  *_test.dart
```

Nota: el antiguo directorio `lib/app/` fue eliminado. Si el IDE muestra pestañas antiguas como `lib/app/persistencia_partida.dart`, son rutas obsoletas. La persistencia vive ahora en `lib/infrastructure/persistence/`.
