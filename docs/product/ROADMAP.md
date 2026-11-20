# Hoja de ruta — Chess Zerox

> Estado: 20 de noviembre de 2026. Este documento es la fuente de verdad de **lo que viene**.
> El plan general y las decisiones de producto están en `PLAN.md`; el diseño del caché en
> `CACHE_Y_MARCA.md`.

## 0. Dónde estamos

Terminado y verificado:

- Repo público en `https://github.com/Zer0x25/Chess-Zerox`, sincronizado con `origin/main`.
- Importación desde Chess.com y Lichess (por usuario, sin login) y desde PGN, en español.
- Lista de usuarios y partidas guardadas, con acceso directo desde «Datos de importación».
- Revisión local con Stockfish 19: informe con precisión/ACPL, momentos clave y etiquetas
  propias («Jugada estrella», «Ocasión perdida», «Error grave»). Son **estimaciones locales**,
  no resultados de Chess.com ni del servidor de Lichess.
- Informes guardados en SQLite para PGNs importados: se reutilizan al reabrir la partida y se
  invalidan si cambia el PGN. La lista de partidas muestra «✓ Revisión local guardada».
- Modo revisión Zerox opcional en el análisis: insignia en la casilla de la jugada, tarjeta
  «Revisión local · jugada anterior» con su alternativa y navegación sincronizada. «Modo Lichess»
  devuelve la vista original, que sigue siendo la predeterminada.
- Cliente OAuth propio (`chess-zerox`, esquema `org.chesszerox.app://login-callback`) con scopes
  mínimos; la sesión se conserva al actualizar la app.
- `flutter analyze` limpio y suite completa de tests en verde.
- Flujo validado en dispositivo Android 16 (arm64): importar → analizar → revisar → informe,
  instalando como actualización (mismo paquete y firma) sin borrar datos.

## 1. Adelgazo del fork: navegación original + capa de análisis

Se conserva la **navegación original de Lichess** (Home / Puzzles / Learn / Watch / More). La
revisión local es una capa opcional sobre el análisis, accesible desde Más → Herramientas y desde
la importación, como en Lichess.

### 1.1 Navegación restaurada

La enum de `BottomTab` vuelve a ser `home, puzzles, learn, watch, more` y la barra a tener
los 5 items originales. No se quita ninguna pestaña ni cambia el enum en ningún momento del
código actual: el botón «Análisis» no existe como pestaña, toda la revisión es por rutas
(`pushHidingTabBar`).

### 1.2 Contenido adelgazado

Solo se adelgazó el contenido, no la navegación:

| Pestaña | Contenido |
|---|---|
| **Home** | Como el original, pero sin el botón de Donar y sin «Acerca de Lichess…» en la bienvenida (decisión del usuario) |
| **Puzzles** | Como el original (sin cambios) |
| **Learn** | Como el original (sin cambios) |
| **Watch** | Como el original (sin cambios) |
| **Más** | Herramientas (importar, análisis, explorador, editor, reloj), Preferencias (ajustes y datos de importación) y Acerca de; sin Comunidad/Donaciones y sin la sección de cuenta del mismo (el login sigue accesible desde Más, como en Lichess) |

### 1.3 Puerta de login del servidor de análisis

La parte de análisis que exigía cuenta — el «Solicitar análisis del ordenador» de la app
original (`server_analysis`) — está oculta: ningún botón ahí toca la palabra «cuenta» y
la app no muestra paredes de login. El **informe local de revisión** no la necesita:
corre Stockfish en el dispositivo, sin cuenta.

## 2. Trabajo completado (validado en código y en dispositivo)

- [x] **R1. Revertir la navegación a los 5 tabs originales** — `BottomTab` vuelve a ser
      `home, puzzles, learn, watch, more`; el análisis sigue accesible desde Más → Herramientas
      y desde la importación (rutas ocultas a la barra).
- [x] **R2. Adelgazar Home y Más** — Home sin «Donar» ni «Acerca de Lichess…» en la bienvenida;
      Más con Herramientas y Preferencias; sin Comunidad/Donaciones.
- [x] **R3. Revisar partida sin login** — oculto el «Solicitar análisis del ordenador»
      (`server_analysis`): la revisión local corre sin cuenta.
- [x] **R4. Migración sqflite + `ImportedGameStore`** — base de datos v10 con tablas
      `import_sources` e `imported_games` y cursor por fuente/usuario.
- [x] **R5. Conectar la pantalla de importación al almacén** — la búsqueda guarda las partidas
      con PGN, filtra por `last_played_at` y permite actualizar sin duplicados.
- [x] **R6. Preferencias de datos** — pantalla «Datos de importación» con lista de usuarios,
      nº de partidas, borrado por usuario o todo con confirmación, y acceso a las partidas.
- [x] **R7. Revisiones persistentes** — tabla `local_game_review` (BD v11), clave por PGN con
      hash SHA-256; se cargan al reabrir la partida y se borran al eliminar el usuario importado.
- [x] **R8. Modo revisión Zerox** — toggle opcional en el análisis con insignia, tarjeta de la
      jugada anterior y su alternativa; «Modo Lichess» restaura la vista original.

## 3. Siguiente

- [ ] **R9. Detección de sacrificios / «Jugada brillante»** — investigación recogida en
      `docs/product/IDEA_SACRIFICIOS.md`. Diferido: no se reclama equivalencia con Chess.com.
- [ ] **R10. Líneas del motor visibles en el modo revisión** — mostrar las líneas en vivo
      junto a la revisión guardada y navegación a momentos clave.
- [ ] Reducir el tráfico de las APIs de importación: hoy el cursor evita duplicados, pero se
      siguen consultando las mismas 10/30/100 partidas.

## 4. Rebrand técnico (pendiente)

- [x] Cliente OAuth propio (`chess-zerox`) y esquema de callback propio con scopes mínimos.
- [ ] `applicationId` propio, icono y splash (el logo de Lichess aparece al arrancar).
- [ ] Deep links HTTPS (el esquema propio ya funciona; falta `assetlinks.json` con la huella
      de la clave de firma definitiva).
- [ ] Decisión sobre Firebase (quitarlo o proyecto propio).
- [ ] Sustituir `dev@chesszerox.local` del `User-Agent` por un contacto real.
- [ ] Clave de firma de release definitiva: hoy se firma con la debug keystore para poder
      actualizar sin perder datos.

## 4.1 Compilaciones

- Release universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`): ~235 MB.
- Release arm64-only: ~94 MB, pensada para móviles modernos; no instala en 32-bit ni x86.
- Ambas mantienen el paquete `org.lichess.mobileV2.debug` y la firma debug para instalar
  como actualización y conservar sesión, partidas y revisiones.
- La señal de finalización del motor aceleró una revisión de 114 s a 77 s en una pasada de
  prueba, pero falló en otra ejecución: **no se adoptó** por falta de fiabilidad y de
  comparación completa de clasificaciones.

## 5. Más adelante (según `PLAN.md` fases 4-5)

- Entrenamiento a partir de errores y cuaderno de repaso espaciado.
- Caché de informes y modo offline completo.
- Beta, GitHub Releases / F-Droid, manual y política de privacidad.

## Convención de trabajo

1. Cada cambio: `dart format` sobre los archivos tocados + `flutter analyze` en esos archivos.
2. Antes de dar por terminada una tanda: `flutter analyze lib test` y `flutter test`.
3. Validar en dispositivo cuando esté conectado, instalando como actualización con la misma
   firma para no perder datos.
