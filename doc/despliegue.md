# Guia de despliegue

Esta guia recoge el plan de despliegue previsto para el proyecto cuando se
copie a la maquina de casa. La idea actual es:

- Backend Dart ejecutandose en casa.
- PostgreSQL en casa, con SQLite como respaldo.
- Front compilado como aplicacion Windows.
- Front compilado como APK Android.
- Front compilado para iOS si se dispone de macOS, Xcode y firma de Apple.
- Front web desplegado en un servicio de hosting estatico.

## Arquitectura objetivo

```text
Windows / Android / iOS / Web
        |
        | HTTP/WebSocket hacia el puerto publico del backend
        v
Backend Dart en casa
        |
        | Conexion local a PostgreSQL
        v
PostgreSQL

Backend Dart
        |
        | Respaldo local si PostgreSQL falla
        v
SQLite
```

El cliente nunca se conecta directamente a PostgreSQL. La app solo habla con el
backend mediante HTTP y WebSocket.

## Backend en casa

En la maquina de casa debe existir el monorepo completo o, como minimo:

```text
backend/
packages/
```

El servidor depende de `packages`, por eso esas carpetas deben mantener
la misma relacion de rutas que en desarrollo.

### Configuracion `.env`

En `backend/.env`:

```env
FOR_HOST=0.0.0.0
FOR_PORT=8080
FOR_PLAYERS=2
FOR_DB=postgres://usuario:password@localhost:5432/foundations_rome
FOR_SQLITE_FALLBACK=fallback.sqlite3
FOR_ACCESS_TOKEN=
FOR_RESTORE_ROOMS=false
```

Notas:

- `FOR_HOST=0.0.0.0` permite conexiones desde otros dispositivos.
- `FOR_PORT=8080` es el puerto del backend.
- `5432` es el puerto interno de PostgreSQL.
- `FOR_SQLITE_FALLBACK` guarda una copia local por si PostgreSQL no esta
  disponible.
- Si se activa `FOR_ACCESS_TOKEN`, los clientes tendran que incluir ese token
  para crear o unirse a partidas.

### Arranque

Desde la maquina de casa:

```bash
cd backend
dart pub get
dart run bin/start_server.dart
```

Si se usa Windows:

```powershell
cd backend
dart pub get
dart run bin/start_server.dart
```

El comando carga automaticamente `backend/.env`.

### Comprobaciones locales

En el navegador de la misma maquina:

```text
http://127.0.0.1:8080/health
http://127.0.0.1:8080/leaderboard
http://127.0.0.1:8080/games
```

Desde otro dispositivo de la misma red:

```text
http://IP_LOCAL_DE_LA_MAQUINA:8080/health
```

Ejemplo:

```text
http://192.168.1.50:8080/health
```

Si eso responde, el backend ya esta accesible dentro de la red local.

## Acceso desde fuera de casa

Para que un jugador se conecte desde internet al backend de casa hay tres
opciones habituales.

### Opcion A: abrir puerto en el router

Configurar redireccion de puertos:

```text
Puerto externo 8080 -> IP local de la maquina de casa:8080
```

Despues el cliente podria usar:

```text
ws://IP_PUBLICA:8080
```

Si la IP publica cambia, conviene usar DNS dinamico, por ejemplo un dominio tipo:

```text
mi-servidor.duckdns.org
```

Entonces el cliente usaria:

```text
ws://mi-servidor.duckdns.org:8080
```

### Opcion B: tunel HTTPS/WSS

Para publicar el front web en un hosting con `https://`, el navegador suele
bloquear WebSocket inseguro `ws://`. En ese caso el backend debe exponerse como
`wss://`.

Una forma comoda es usar un tunel o proxy que convierta:

```text
wss://dominio-publico/ws
```

en:

```text
ws://127.0.0.1:8080
```

Esto evita abrir directamente el puerto del router y soluciona el problema de
HTTPS/WSS del navegador.

### Opcion C: reverse proxy en casa

Otra opcion mas avanzada es usar Nginx, Caddy o Apache en la maquina de casa:

```text
https://api.midominio.com -> backend Dart en localhost:8080
wss://api.midominio.com  -> WebSocket del backend Dart
```

Esta opcion requiere certificado TLS, dominio y configuracion de proxy para
WebSocket.

## Compilar front para Windows

La compilacion de Windows debe hacerse desde una maquina Windows con Flutter
preparado para escritorio.

Desde la carpeta Flutter:

```bash
cd frontend
flutter pub get
flutter build windows --release
```

Salida esperada:

```text
frontend/build/windows/x64/runner/Release/
```

Esa carpeta contiene el ejecutable y los archivos necesarios. Para probarlo,
abrir:

```text
Foundations of Rome.exe
```

El nombre exacto del ejecutable puede variar segun la configuracion del proyecto.

### Conexion desde Windows al backend

En modo remoto, la app debe apuntar al servidor de casa:

```text
ws://IP_LOCAL_O_PUBLICA:8080
```

Ejemplos:

```text
ws://192.168.1.50:8080
ws://mi-servidor.duckdns.org:8080
wss://api.midominio.com
```

## Compilar front para Android

La compilacion de Android requiere Flutter con Android SDK configurado.

Desde la carpeta Flutter:

```bash
cd frontend
flutter pub get
flutter build apk --release --split-per-abi
```

Salida esperada:

```text
frontend/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Ese APK se puede instalar en un dispositivo Android moderno de 64 bits. En un
movil como Redmi Note 10 5G, la variante recomendada es
`app-arm64-v8a-release.apk`.

Para compilar un APK universal se puede usar:

```bash
flutter build apk --release
```

Para generar un App Bundle, util para publicacion en Google Play:

```bash
flutter build appbundle --release
```

Salida esperada:

```text
frontend/build/app/outputs/bundle/release/app-release.aab
```

### Conexion desde Android al backend

Si el movil esta en la misma red WiFi que el backend:

```text
ws://IP_LOCAL_DE_LA_MAQUINA:8080
```

Si el movil esta fuera de casa:

```text
ws://IP_PUBLICA_O_DNS:8080
```

Si el backend se publica con HTTPS/TLS:

```text
wss://api.midominio.com
```

Nota importante: si el APK de release no conecta usando `ws://IP:8080`, Android
puede estar bloqueando trafico no cifrado. Para una demo local hay dos caminos:

- usar `wss://` mediante tunel, dominio o proxy con TLS;
- permitir trafico claro en `android/app/src/main/AndroidManifest.xml` con
  `android:usesCleartextTraffic="true"` dentro de `<application>`.

Para un despliegue publico es preferible usar `wss://` y no depender de trafico
claro.

### Visor 3D en Android

El tablero 3D en Android se muestra dentro de un WebView. La app levanta un
servidor local temporal en `127.0.0.1` para servir el HTML de Three.js y los
assets del juego al WebView.

Por ese motivo el `AndroidManifest.xml` principal debe mantener:

```xml
<application
    ...
    android:usesCleartextTraffic="true">
```

Si se elimina, el WebView puede mostrar:

```text
net::ERR_CLEARTEXT_NOT_PERMITTED
```

Ademas, las llamadas de `window_manager` deben limitarse a escritorio. En
Android ese plugin no existe y produce:

```text
MissingPluginException(No implementation found for method setMinimumSize)
```

En Android la app usa un modo de menor consumo para el visor 3D:

- fondo `fondo_mobile.webp` en lugar de usar el EXR como fondo visual;
- render bajo demanda, no continuo;
- limpieza de cache GLB cuando un modelo deja de tener instancias en escena;
- miniaturas de edificios como posters `.webp` en vez de videos.

Para builds Android optimizadas, `pubspec.yaml` puede incluir solo:

```yaml
- assets/thumbnails/posters/
```

Si se quiere mantener video animado de miniaturas en escritorio, hay que incluir
los `.mp4` en una build de escritorio o volver a declarar `assets/thumbnails/`.

### UI del tablero en Android

El tablero se fuerza a orientacion horizontal en movil para que entren el visor
3D, mercado, HUD de jugadores y toolbar.

La UI movil usa controles compactos:

- mercado y badge de era mas estrechos;
- jugadores como chips en columna inferior izquierda, con estadisticas solo en
  el jugador activo;
- boton de rotacion tactil en la toolbar para sustituir la rueda del raton;
- boton `X` tactil para cancelar la colocacion de un edificio antes de
  confirmarlo;
- dialogo de estadisticas al tocar un jugador.

## Compilar front para iOS

La compilacion de iOS requiere macOS con Xcode instalado. A diferencia de
Android, no basta con generar un archivo equivalente a un APK: Apple exige
firmado, certificados y perfiles de provisionamiento para instalar en
dispositivos reales o distribuir la app.

Para probar en simulador:

```bash
cd frontend
flutter pub get
flutter devices
flutter run -d <id_del_simulador>
```

Para compilar en modo release:

```bash
cd frontend
flutter build ios --release
```

Para generar un `.ipa` distribuible:

```bash
flutter build ipa --release
```

Si falla el firmado, abre el workspace de iOS en Xcode y revisa `Signing &
Capabilities`:

```bash
open ios/Runner.xcworkspace
```

En iOS se aplican las mismas consideraciones de backend que en Android: en red
local se puede usar `ws://IP_LOCAL:8080`; para despliegue publico es preferible
usar `wss://` con dominio o proxy TLS.

## Desplegar front web

Flutter web genera archivos estaticos. Se compila con:

```bash
cd frontend
flutter pub get
flutter build web --release
```

Salida esperada:

```text
frontend/build/web/
```

Esa carpeta se puede subir a un hosting estatico como:

- Cloudflare Pages.
- Netlify.
- Vercel.
- Firebase Hosting.
- GitHub Pages.

El hosting solo sirve archivos. No ejecuta el backend ni conecta con la BBDD.

Si se publica la web en la raiz del dominio, por ejemplo
`https://mi-front.com/`, no hace falta cambiar nada. Si se publica dentro de una
ruta, por ejemplo `https://mi-front.com/foundations/`, puede ser necesario
compilar indicando el `base-href`:

```bash
flutter build web --release --base-href /foundations/
```

### Conexion desde web al backend de casa

Si el hosting publica la app en:

```text
https://mi-front.com
```

el backend debe estar disponible como:

```text
wss://api.midominio.com
```

No es recomendable depender de:

```text
ws://IP_PUBLICA:8080
```

desde una pagina `https://`, porque muchos navegadores lo bloquearan por
contenido mixto.

Para pruebas locales, en cambio, si se abre la app desde `http://localhost` se
puede usar:

```text
ws://127.0.0.1:8080
ws://192.168.1.50:8080
```

## Orden recomendado de despliegue

1. Arrancar PostgreSQL en casa.
2. Arrancar el backend con `FOR_HOST=0.0.0.0`.
3. Probar `/health` desde la propia maquina.
4. Probar `/health` desde otro dispositivo de la red local.
5. Compilar Windows y probar modo remoto contra la IP local.
6. Compilar Android y probar modo remoto contra la IP local.
7. Opcionalmente, compilar iOS desde macOS/Xcode y probar contra la IP local.
8. Decidir como exponer el backend fuera de casa:
   - puerto abierto en router;
   - tunel HTTPS/WSS;
   - reverse proxy con dominio.
9. Compilar Flutter web y subir `build/web/` al hosting estatico.
10. Probar que la web se conecta al backend usando `wss://`.

## Checklist antes de una demo

- PostgreSQL iniciado.
- Backend iniciado.
- `http://127.0.0.1:8080/health` responde.
- `http://IP_LOCAL:8080/health` responde desde otro dispositivo.
- El firewall permite conexiones al puerto `8080`.
- Si se juega desde internet, el dominio o tunel apunta a la maquina de casa.
- Si el front web esta en HTTPS, el backend usa WSS.
- `FOR_RESTORE_ROOMS=false` para empezar demos con salas limpias.
- `FOR_SQLITE_FALLBACK` configurado.

## Que queda para un despliegue mas profesional

Para una version mas robusta se podria anadir:

- Servicio de sistema para arrancar el backend automaticamente.
- Docker para backend y PostgreSQL.
- Reverse proxy con TLS.
- Logs persistentes.
- Copias de seguridad programadas.
- Dominio propio.
- Monitorizacion simple de `/health`.
