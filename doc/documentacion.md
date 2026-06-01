# Documentacion tecnica del monorepo tfgFoR

Este directorio contiene la documentacion de mantenimiento de la aplicacion. El objetivo es que una persona nueva pueda entender que hace cada capa, como fluye el estado y donde tocar cuando cambie una regla, una pantalla, el visor 3D o el modo remoto.

## Lectura recomendada

1. [Arquitectura](arquitectura.md)
2. [Estructura del monorepo](estructura_monorepo.md)
3. [Modulos principales de la aplicacion](modulos_app.md)
4. [Funcionamiento de la aplicacion explicado paso a paso](funcionamiento_aplicacion.md)
5. [Flujo de datos](flujo_datos.md)
6. [Logica del juego](logica_juego.md)
7. [Interfaz Flutter](interfaz_flutter.md)
8. [Visor 3D](visor_3d.md)
9. [Persistencia, audio e infraestructura](infraestructura.md)
10. [Modo remoto y ranking](modo_remoto.md)
11. [Despliegue VPS actual](despliegue_vps_fortfg.md)
12. [Guia de despliegue local y multiplataforma](despliegue.md)
13. [Guia de mantenimiento](mantenimiento.md)

## Estado actual

`frontend` es una aplicacion Flutter multiplataforma para una adaptacion digital de Foundations of Rome. La aplicacion incluye:

- Partida local con jugadores humanos y bots.
- Partida remota por WebSocket.
- Motor de reglas compartido entre Flutter, CLI y servidor Dart.
- Visor 3D con Three.js embebido en web y escritorio.
- Guardado/carga de partida en web y archivo local en plataformas no web.
- Ranking global persistido con SQLite o PostgreSQL en el servidor.
- Audio multiplataforma.

El repositorio se organiza como monorepo:

- `frontend/`: app Flutter.
- `packages/`: motor de reglas, modelos compartidos y protocolo remoto.
- `backend/`: backend Dart independiente.

## Estructura principal

```text
frontend/lib/
  main.dart
  app_entrypoint.dart  # Arranque Flutter, rutas principales y callbacks globales.
  application_config.dart
  controlador_tablero.dart
  application/       # Coordinacion de casos de uso y servicios de aplicacion.
  infrastructure/    # Adaptadores externos: audio, persistencia y sesion remota.
  presentation/      # Pantallas y widgets Flutter.
  visor_3d/          # Subsistema visual 3D y puentes por plataforma.
  for_cli_app.dart   # Aplicacion CLI reutilizable desde bin/for_cli.dart.

frontend/bin/
  for_cli.dart

packages/lib/
  core.dart          # Entrada publica del motor de reglas.
  protocol.dart      # Entrada publica del protocolo remoto.
  core/              # Modelo de negocio y reglas puras.
  protocol/          # Mensajes, campos y tipos del protocolo remoto.

backend/
  bin/start_server.dart
  lib/        # HTTP, WebSocket, salas, ranking y persistencia.

frontend/test/
  *_test.dart
```

Nota: el antiguo directorio `lib/app/` fue eliminado. Si el IDE muestra pestañas antiguas como `lib/app/persistencia_partida.dart`, son rutas obsoletas. La persistencia vive ahora en `lib/infrastructure/persistence/`.

Nota: tambien son obsoletas referencias antiguas a `lib/juego/`, `lib/FoR/`,
`infrastructure/online/`, `infrastructure/leaderboard/` o
`infrastructure/startup/`. En la estructura actual, el controlador del tablero
esta en `lib/controlador_tablero.dart`, la sesion remota en
`lib/infrastructure/sesion_remota.dart`, el ranking del servidor en
`backend/lib/persistence/` y el arranque de plataforma en
`lib/application_config.dart`.
