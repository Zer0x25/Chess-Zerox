# Hoja de ruta — Chess Zerox

> Estado: 19 de noviembre de 2026. Este documento es la fuente de verdad de **lo que viene**.
> El plan general y las decisiones de producto están en `PLAN.md`; el diseño del caché en
> `CACHE_Y_MARCA.md`.

## 0. Dónde estamos

Terminado y verificado:

- Repo público en `https://github.com/Zer0x25/Chess-Zerox` (HEAD `31c45ed9e`).
- Importación desde Chess.com y Lichess (por usuario, sin login) y desde PGN, en español.
- Revisión local con Stockfish 19: informe con precisión/ACPL, momentos clave y etiquetas
  propias («Jugada estrella», «Ocasión perdida», «Error grave»).
- `flutter analyze` limpio y 2.386 tests en verde.
- Flujo real validado en móvil: importar → analizar → revisar → informe.

## 1. Adelgazo del fork: navegación original + capa de análisis

El usuario ha revertido la reducción: la app vuelve a la **navegación original de Lichess**
(Home / Puzzles / Learn / Watch / More). Se conserva el eje de análisis: la revisión local sigue
accesible desde Más → Herramientas → Análisis y desde la importación (como siempre en Lichess).

### 1.1 Navegación restaurada

La enum de `BottomTab` vuelve a ser `home, puzzles, learn, watch, more` y la barra a tener
los 5 items originales. No se quita ninguna pestaña ni cambia el enum en ningún momento del
código actual: el botón «Análisis» no existe como pestaña, toda la revisión es por rutas
(`pushHidingTabBar`), y es así como funciona Lichess.

### 1.2 Contenido adelgazado

Solo se adelgonzó el contenido, no la navegación:

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
Corre Stockfish en el dispositivo, sin Login.

## 2. Trabajo en curso (ahora, en ausencia del teléfono)

El teléfono no está disponible, así que se avanza solo con código verificable por
`flutter analyze` y `flutter test` (sin validación en dispositivo).

- [x] **R1. Revertir la navegación a los 5 tabs originales** — `BottomTab` vuelve a ser
      `home, puzzles, learn, watch, more` (Home/Puzzles/Learn/Watch/More); se quitó la pestaña
      Análisis, sus `navigator key`/`scroll controller`/interacción. El análisis sigue accesible
      desde Más → Herramientas y desde la importación (rutas ocultas a la barra).
- [x] **R2. Adelgazar Home y Más** — Home sin «Donar» ni «Acerca de Lichess…» en la bienvenida;
      Más con Herramientas (importar, análisis, explorador, editor, reloj), Preferencias (ajustes y
      datos de importación) y Acerca de; sin Comunidad/Donaciones.
- [x] **R3. Revisar partida sin login** — oculto el «Solicitar análisis del ordenador» de
      `server_analysis` (puerta de login): la revisión local de Stockfish corre sin cuenta.

## 3. Siguiente: caché e importación incremental

Según `CACHE_Y_MARCA.md`:

- [x] **R4. Migración sqflite + `ImportedGameStore`** — base de datos v10 con tablas
      `import_sources` e `imported_games`, cursor por fuente/usuario, tests sin red (7 tests).
- [x] **R5. Conectar la pantalla de importación al almacén** — la búsqueda guarda las partidas con
      PGN, filtra por el cursor `last_played_at`, muestra «N partidas nuevas» / «No hay partidas
      nuevas», el botón pasa a «Actualizar» y se puede elegir 10/30/100. Test de importar y
      actualizar sin duplicados.
  - Limitación conocida: el cursor evita guardar duplicados, pero las APIs siguen consultando el
    mismo número de partidas; el ahorro de tráfico total queda para el siguiente paso.
- [x] **R6. Preferencias de datos** — nueva pantalla «Datos de importación» desde Más →
      Preferencias: lista usuarios guardados con nº de partidas, borrado por usuario o todo con
      confirmación, y estado vacío. Test de borrado.

## 4. Después: rebrand técnico (requiere decisiones del usuario)

- [ ] `applicationId` propio, icono, splash (el logo de Lichess aparece al arrancar), deep links.
- [ ] Decisión sobre Firebase (quitarlo o proyecto propio) y cliente OAuth propio.
- [ ] Sustituir `dev@chesszerox.local` del `User-Agent` por un contacto real.

## 5. Más adelante (según `PLAN.md` fases 4-5)

- Entrenamiento a partir de errores y cuaderno de repaso espaciado.
- Caché de informes y modo offline completo.
- Beta, GitHub Releases / F-Droid, manual y política de privacidad.

## Convención de trabajo mientras no está el teléfono

1. Cada cambio: `dart format` sobre los archivos tocados + `flutter analyze` en esos archivos.
2. Antes de dar por terminada una tanda: `flutter analyze lib test` y los tests afectados.
3. No se toca nada que requiera validación en dispositivo (arranque, splash, icono) sin el móvil.
