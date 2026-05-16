# prueba_tfg

Aplicacion Flutter de Foundations of Rome.

## Ejecutar en Android (emulador o dispositivo)

1. Abre un emulador Android desde Android Studio (AVD Manager).
2. En la raiz del proyecto, ejecuta:

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

## Troubleshooting en Windows

- Si el SDK de Flutter esta en una ruta con espacios, el build puede fallar.
- Recomendado: usar un path sin espacios (por ejemplo `C:\flutter`) y asegurar que ese `bin` este primero en `PATH`.
