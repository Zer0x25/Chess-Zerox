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

- [ ] **R1. Simplificar la barra de pestañas** — quitar Ejercicios/Aprender/Ver de la enum,
      del `NavigationBar` y de las rutas de la barra; dejar Inicio / Analizar / Más.
- [ ] **R2. Reordenar «Más»** — agrupar Herramientas (importar), Preferencias y Acerca de;
      sacar Donaciones/Comunidad del «Inicio» visible.
- [ ] **R3. Ajustar textos y tests** — actualizar etiquetas Traducidas y los tests de navegación
      que asumen el conjunto antiguo de pestañas.

## 3. Siguiente: caché e importación incremental

Según `CACHE_Y_MARCA.md`:

- [ ] **R4. Migración sqflite + `ImportedGameStore`** — tablas `import_sources` e
      `imported_games`, con tests sin red.
- [ ] **R5. Conectar la pantalla de importación al almacén** — listar guardadas, cursor
      `last_played_at`, mostrar «N partidas nuevas», botón Actualizar y elegir 10/30/100.
- [ ] **R6. Preferencias de datos** — borrar usuarios/partidas guardadas desde «Más».

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
