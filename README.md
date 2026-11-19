# Chess Zerox

**Analizador y entrenador de ajedrez para Android, gratuito y open source.**

> Nombre provisional. Estado: fork de Lichess Mobile en desarrollo; la primera vertical (importar
> una partida de Lichess o Chess.com y abrirla en el tablero de análisis) ya está implementada.

## Estado actual

La base es un fork de [lichess-org/mobile](https://github.com/lichess-org/mobile) (GPLv3), sin
modificar su motor de ajedrez ni su tablero. Sobre esa base ya funciona:

- Pantalla **Importar partida** (Más → Import game) con tres fuentes: Lichess, Chess.com y PGN.
- Listado de partidas públicas por usuario de Lichess, reutilizando el cliente y los repositorios
  existentes.
- Cliente de la **Published-Data API de Chess.com**: peticiones en serie, `User-Agent` propio,
  caché en memoria de 12 horas y revalidación con `ETag`/`Last-Modified`.
- Apertura de cualquier partida importada en el **tablero de análisis** existente, con evaluación
  local de Stockfish 19 NNUE y navegación por la partida.
- Tests de unidad del cliente de Chess.com y tests de widget del flujo de importación, sin llamadas
  reales a las APIs.

Pendiente para las siguientes verticales: informe de precisión y clasificación de jugadas,
entrenamiento de errores, rebranding completo (iconos, `applicationId`, OAuth de Lichess) y
sustituir Firebase por una configuración propia o desactivarlo.

### Ejecutar en desarrollo

```bash
flutter pub get
dart run build_runner build

# La app usa lichess.dev por defecto. Para importar partidas reales de Lichess:
flutter run \
  --dart-define=LICHESS_HOST=lichess.org \
  --dart-define=LICHESS_WS_HOST=socket.lichess.org

# Tests de la vertical de importación
flutter test test/model/import test/view/import
```

## La idea en una frase

Importa tus partidas de Lichess y Chess.com (o un PGN), analízalas en el teléfono con Stockfish 19 NNUE y recibe un informe claro: precisión, errores, mejores jugadas y ejercicios para no repetir los mismos fallos.

No queremos competir con Lichess ni con Chess.com. Queremos ser la capa de análisis y entrenamiento que hoy está detrás de un muro de pago o dispersa entre plataformas.

## Por qué esta base y no empezar de cero

La app [lichess-org/mobile](https://github.com/lichess-org/mobile) ya trae, en Flutter y GPLv3:

- Tablero, editor de posiciones y análisis interactivo.
- Stockfish 19 con redes NNUE, ejecutándose en el dispositivo.
- Explorador de aperturas, tabla de finales y análisis de servidor de Lichess.
- Importación de PGN, modo "aprende de tus errores", temas, i18n y accesibilidad.
- Cliente de la API de Lichess con OAuth PKCE, caché y manejo de límites.

Eso es aproximadamente el 60-70 % de un analizador. Lo que falta para el producto que quieres es concreto:

1. Importar partidas de Chess.com y unificarlas con las de Lichess.
2. Generar un **informe completo de partida para cualquier PGN**, no solo para partidas archivadas de Lichess.
3. Clasificar cada jugada y explicar los errores en español.
4. Convertir los errores en ejercicios y repaso espaciado.
5. Una capa visual propia, clara y atractiva, inspirada en la experiencia de Chess.com pero sin copiar sus assets, nombres ni diseño.

## Qué aporta frente a Lichess y Chess.com

| Necesidad | Lichess | Chess.com | Chess Zerox |
|---|---|---|---|
| Análisis con motor fuerte | Sí, gratis | Sí, revisión completa de pago | Local y gratis, con modo profundo |
| Importar desde la otra plataforma | No | No | Lichess + Chess.com + PGN |
| Funciona sin cuenta | Sí | Limitado | Sí |
| Funciona sin conexión | Parcial | No | Sí, el motor es local |
| Explicaciones en español | Interfaz traducida | De pago | Entrenador con texto en español |
| Entrenar tus errores | Por partida | De pago | Base de errores + repaso espaciado |
| Código abierto | Sí | No | Sí, GPLv3 |

La diferencia no es "un motor más fuerte". Lichess ya usa Stockfish de primer nivel en servidor. La diferencia es **aprovechar ese análisis para enseñar**: clasificar, explicar, priorizar y convertir los errores en práctica.

## Alcance del MVP

- Importar las últimas N partidas por usuario de Lichess y Chess.com.
- Importar PGN/FEN y compartir una partida desde otra app.
- Revisión local de una partida completa con progreso y cancelación.
- Informe: precisión, ACPL, gráfico de evaluación, clasificación de jugadas y momentos clave.
- Tablero con barra de evaluación, flecha de la mejor jugada y navegación por la lista de movimientos.
- Entrenamiento de los errores de la partida.
- Caché de informes y modo offline.
- Español e inglés; el resto de idiomas se hereda de Lichess.

Fuera del MVP: jugar online, torneos, social, detección de trampas, análisis en la nube propio, clone visual de Chess.com.

## Stack

- **Flutter 3.50 / Dart 3.14** (fork de Lichess Mobile).
- **Stockfish 19 NNUE** mediante `multistockfish`, el motor que ya usa la app.
- **dartchess** para reglas, PGN y variantes.
- **chessground** para el tablero.
- **Riverpod** para estado.
- **sqflite** para caché local.
- **fl_chart** para el gráfico de evaluación.
- **API oficial de Lichess** y **Published-Data API de Chess.com**. Nada de endpoints internos ni scraping.

## Documentos

- [Plan de producto y roadmap](docs/product/PLAN.md)
- [Arquitectura técnica](docs/product/ARQUITECTURA.md)
- [Importación desde Lichess y Chess.com](docs/product/IMPORTACION.md)
- [Caché, importación incremental y marca](docs/product/CACHE_Y_MARCA.md)
- [Referencias de UX](docs/product/UX_REFERENCIAS.md)
- [Licencias, marcas y cumplimiento](docs/product/LEGAL.md)
- [README original de Lichess Mobile](docs/upstream/README.md) (base del fork)

## Aviso legal

Este proyecto no está afiliado, patrocinado ni respaldado por Lichess ni por Chess.com. "Lichess" y "Chess.com" son marcas de sus respectivos titulares y se usan únicamente para indicar compatibilidad.

El fork de Lichess Mobile está bajo **GNU GPLv3**. Si distribuyes la app, debes publicar el código fuente correspondiente y conservar las licencias y avisos. Lee [docs/product/LEGAL.md](docs/product/LEGAL.md) antes de publicar.
