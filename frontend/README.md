# frontend

Aplicacion Flutter de Foundations of Rome.

Este paquete forma parte del monorepo `tfgFoR`, junto con:

- `../packages/`: motor de reglas y modelos compartidos.
- `../backend/`: backend Dart independiente.

## Documentacion

La documentacion principal esta en [`../doc/documentacion.md`](../doc/documentacion.md).

La estructura general del repositorio esta explicada en [`../doc/estructura_monorepo.md`](../doc/estructura_monorepo.md).

Para una explicacion paso a paso y poco tecnica del flujo completo de la app, empieza por [`../doc/funcionamiento_aplicacion.md`](../doc/funcionamiento_aplicacion.md).

## Ejecutar en Android (emulador o dispositivo)

1. Abre un emulador Android desde Android Studio (AVD Manager).
2. Desde esta carpeta `frontend`, ejecuta:

```bash
flutter pub get
flutter devices
flutter run -d <deviceId>
```

Si solo tienes un dispositivo Android activo, puedes usar directamente:

```bash
flutter run
```

## Verificacion rapida

```bash
flutter analyze
```

## Build Android recomendado

```bash
flutter build apk --release --split-per-abi
```

Para moviles Android modernos de 64 bits se usa normalmente:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

La build movil usa posters `.webp` para miniaturas de edificios; no necesita
empaquetar los videos `.mp4` de `assets/thumbnails/`.

## Troubleshooting en Windows

- Si el SDK de Flutter esta en una ruta con espacios, el build puede fallar.
- Recomendado: usar un path sin espacios (por ejemplo `C:\flutter`) y asegurar que ese `bin` este primero en `PATH`.
