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

## 1. Dirección nueva: interfaz mínima centrada en análisis

El usuario ha decidido que la app **no es un cliente de juego ni de consumo de contenido**.
La interfaz debe quedar simple y minimizada, con el análisis/revisión como eje.

### 1.1 Pestañas que se QUITAN de la barra inferior

Estas secciones no se usarán y dejan de ocupar espacio en la navegación principal:

- **Ejercicios** (puzzles)
- **Aprender** (learn)
- **Ver** (watch)

No se borra su código —sigue en el repo y accesible por rutas internas si algún día se quiere—,
pero desaparecen de la barra de pestañas y de los accesos visibles.

### 1.2 Barra inferior resultado

La navegación se reduce a lo esencial:

| Pestaña | Contenido |
|---|---|
| **Inicio** | Acceso directo a importar partida y a las partidas recientes |
| **Analizar** | Tablero de análisis (donde ya vive «Revisar partida») |
| **Más** | Herramientas, preferencias y Acerca de |

> Nota: el usuario traducirá personalmente el contenido de **Más**. Nosotros preparamos la
> estructura (herramientas / preferencias / acerca de), no el texto final.

### 1.3 Secciones que salen de la navegación principal

- **Donaciones** y **Comunidad** dejan de ser entradas visibles en «Inicio».
- Se reubican dentro de «Más → Acerca de» o se retiran del todo, según decisión del usuario.

## 2. Trabajo en curso (ahora, en ausencia del teléfono)

El teléfono no está disponible, así que se avanza solo con código verificable por
`flutter analyze` y `flutter test` (sin validación en dispositivo).

- [x] **R1. Simplificar la barra de pestañas** — quitar Ejercicios/Aprender/Ver de la enum,
      del `NavigationBar` y de las rutas de la barra; dejar Inicio / Analizar / Más.
- [x] **R2. Reordenar «Más»** — Herramientas (importar, análisis, explorador, editor, reloj),
      Preferencias y Acerca de; fuera Comunidad, Donaciones y la cuenta. También se quitaron
      los botones de Donar/Acerca de la pantalla de bienvenida de Inicio.
- [x] **R3. Ajustar textos y tests** — nueva clave `mobileAnalysisTab` («Análisis» en ES) y tests
      de navegación/importación/análisis actualizados. `flutter analyze` limpio.

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
