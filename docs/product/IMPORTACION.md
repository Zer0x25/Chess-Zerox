# Importación de partidas

## Estado de la implementación

La primera vertical ya está en el repositorio:

| Fuente | Estado | Dónde |
|---|---|---|
| Lichess por usuario | Funciona | `lib/src/model/import/import_repository.dart` |
| Lichess PGN por id | Funciona | `GameRepository.getGamePgn` |
| Chess.com por usuario | Funciona (partidas estándar) | `lib/src/model/import/chesscom_client.dart` |
| PGN pegado o archivo | Funciona (pantalla existente) | `lib/src/view/more/import_pgn_screen.dart` |

Detalles que conviene conocer antes de tocar el código:

- El listado de Lichess reutiliza `GameRepository.getUserGames` (NDJSON) y pide el PGN de la
  partida solo al abrirla, con `Accept: application/x-chess-pgn`. Así no se descargan PGN que el
  usuario no va a abrir.
- El cliente de Chess.com mantiene **una petición en vuelo**, cachea en memoria 12 horas y
  revalida con `ETag`/`Last-Modified`. La caché en disco queda para una fase posterior.
- Chess.com exige identificarse. El `User-Agent` está en `import_providers.dart`; antes de publicar
  hay que sustituir el contacto de ejemplo por uno real.
- Las variantes distintas de `chess` se descartan en Chess.com y se bloquean en la interfaz con un
  aviso: la revisión local asume ajedrez estándar.
- Una partida privada de Chess.com no está en la PubAPI. La ruta soportada es exportar el PGN desde
  Chess.com y usar **Import PGN**.

## Regla de oro

Usar **APIs públicas y documentadas**:

- Lichess: [API oficial](https://lichess.org/api).
- Chess.com: [Published-Data API (PubAPI)](https://www.chess.com/announcements/view/published-data-api).

**No usar endpoints internos**, scraping ni automatización de las webs. En el caso de Chess.com, su User Agreement de 2026 prohíbe explícitamente el acceso automatizado no autorizado, y los endpoints internos cambian sin aviso. La PubAPI ya entrega las partidas públicas, que es lo que necesita el 95 % de los usuarios.

## 1. Lichess

### 1.1 Autenticación

- Las partidas públicas no requieren cuenta.
- Para partidas privadas, favoritas o en curso: OAuth 2.0 con PKCE.
  - Autorización: `https://lichess.org/oauth`
  - Token: `https://lichess.org/api/token`
  - `code_challenge_method=S256`
  - Sin `client_secret`; es un cliente público.
  - El token dura aproximadamente un año; no hay refresh token.
- La app ya tiene `flutter_appauth` y un flujo de login de Lichess; reutilizarlo.
- Cabecera obligatoria `User-Agent` con el nombre de la app y un contacto.

### 1.2 Listar partidas de un usuario

```http
GET https://lichess.org/api/games/user/{username}?max=30&pgnInJson=true&clocks=true&evals=true&opening=true&accuracy=true
Accept: application/x-ndjson
User-Agent: ChessZerox/0.1 (contacto@ejemplo.com)
```

Notas:

- `max` limita el número de partidas.
- `pgnInJson=true` incluye el PGN completo en cada objeto; evita una segunda petición.
- `evals=true` incluye evaluaciones de servidor si existen.
- `clocks=true` incluye relojes.
- `opening=true` incluye apertura/ECO.
- La respuesta es NDJSON: un JSON por línea. La app ya tiene `readNdJsonList`.
- Orden: más recientes primero.
- Filtros útiles: `since`, `until`, `perfType`, `rated`, `color`, `vs`.

### 1.3 Una partida por id o URL

```http
GET https://lichess.org/game/export/{gameId}?pgnInJson=true&evals=true&clocks=true
Accept: application/json
```

- `gameId`: 8 caracteres alfanuméricos.
- También se puede pedir `Accept: application/x-chess-pgn` para recibir solo PGN.
- Para una URL `https://lichess.org/{id}`, extraer el id y llamar al endpoint.

### 1.4 Importar un PGN a Lichess (opcional)

```http
POST https://lichess.org/api/import
Content-Type: application/x-www-form-urlencoded
```

No es necesario para analizar localmente. Solo si el usuario quiere guardar la partida en su cuenta de Lichess.

### 1.5 Límites

- **Una petición a la vez.**
- Exportación de partidas: 20 partidas/s anónimo, 30/s con OAuth, 60/s si son propias.
- Ante `429`: esperar **60 segundos** y bajar el ritmo. No hacer reintentos agresivos.
- Cachear; no volver a pedir lo mismo en cada apertura de pantalla.
- `User-Agent` identificable; sin él, la petición puede ser rechazada.

### 1.6 URLs soportadas

| URL | Acción |
|---|---|
| `https://lichess.org/{8 chars}` | Exportar partida |
| `https://lichess.org/analysis/{fen}` | Abrir posición en el tablero |
| `https://lichess.org/study/{id}` | Importar PGN del estudio (opcional) |
| `https://lichess.org/api/...` | No aceptar como entrada de usuario |

Validar el id contra la API; no confiar solo en la forma de la URL.

## 2. Chess.com

### 2.1 Qué permite la PubAPI

- Datos públicos de jugadores, partidas, clubes y torneos.
- Solo lectura.
- Sin OAuth para datos públicos.
- No incluye partidas privadas ni chat.
- Los datos se refrescan como máximo cada 12 horas.
- Uso comercial permitido según su ayuda de 2026, con condiciones:
  - No abusar ni spamear.
  - No copiar su propiedad intelectual: paleta, piezas, sonidos, glyphs, nombres de funciones, UI/UX.
  - Indicar claramente que el producto no está afiliado a Chess.com.
  - No usar endpoints internos ni scraping.

### 2.2 Perfil

```http
GET https://api.chess.com/pub/player/{username}
User-Agent: ChessZerox/0.1 (contacto@ejemplo.com)
```

Devuelve avatar, país, seguidores, fecha de alta, etc. Útil para la cabecera de la pantalla de importación.

### 2.3 Archivos mensuales

```http
GET https://api.chess.com/pub/player/{username}/games/archives
```

Respuesta:

```json
{
  "archives": [
    "https://api.chess.com/pub/player/ejemplo/games/2026/10",
    "https://api.chess.com/pub/player/ejemplo/games/2026/11"
  ]
}
```

Luego:

```http
GET https://api.chess.com/pub/player/{username}/games/2026/11
```

Respuesta simplificada:

```json
{
  "games": [
    {
      "url": "https://www.chess.com/game/live/123456789",
      "pgn": "[Event \"Live Chess\"]...",
      "time_control": "600",
      "end_time": 1763500000,
      "rated": true,
      "time_class": "rapid",
      "rules": "chess",
      "white": { "rating": 1650, "result": "win", "username": "blancas" },
      "black": { "rating": 1600, "result": "checkmated", "username": "negras" }
    }
  ]
}
```

Notas:

- `rules` puede ser `chess`, `chess960`, `bughouse`, `kingofthehill`, etc. Para el MVP, filtrar `chess`.
- El PGN puede incluir relojes; no siempre incluye `[%eval]`.
- `end_time` es Unix en segundos.
- `time_class`: `bullet`, `blitz`, `rapid`, `daily`.
- No hay endpoint público para "una partida por id". Para una URL:
  1. Extraer el id numérico.
  2. Pedir los archivos de los últimos meses (empezando por el actual) y buscar `url` o `uuid`.
  3. Si no aparece, pedir al usuario que pegue el PGN.
- Para partidas privadas, no hay acceso; ofrecer PGN.

### 2.4 Límites y buenas prácticas

- Peticiones **seriales**; las paralelas pueden devolver `429`.
- Incluir un `User-Agent` con contacto.
- Respetar `ETag`, `Last-Modified`, `Cache-Control`; cachear 12 h.
- Ante `429`: backoff exponencial corto y reintento; si persiste, detener y avisar.
- No descargar todos los archivos históricos de una cuenta grande. Pedir los últimos N meses o el mes que el usuario elija.
- No descargar todos los meses para una sola partida; buscar en un rango acotado.
- Atribución visible: "Datos de partidas de Chess.com. Este proyecto no está afiliado a Chess.com."

### 2.5 Ejemplo de cola serial

```dart
class SerialQueue {
  Future<void> _tail = Future.value();

  Future<T> add<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
```

## 3. PGN, FEN y compartir

- **PGN pegado**: la app ya tiene `ImportPgnScreen.handlePgnText`.
- **Archivo**: `file_picker` ya está integrado.
- **Compartir**: añadir `ACTION_SEND` para `text/plain` y `application/x-chess-pgn`; recibir URL o PGN.
- **FEN**: abrir el editor/análisis existente.
- **Múltiples partidas**: `PgnGame.parseMultiGameLazy` y lista de selección.

### Detección de fuente por texto

| Patrón | Fuente |
|---|---|
| `lichess.org/{8}` | Lichess |
| `chess.com/game/...` | Chess.com (best effort) |
| `[Event "..."` o `1. e4` | PGN |
| FEN con 6 campos | FEN |

No ejecutar peticiones automáticas al pegar una URL sin confirmación del usuario; mostrar una vista previa y el origen.

## 4. Normalización

Todas las fuentes producen un `ReviewGame`:

```dart
ReviewGame(
  id: stableId(source, sourceGameId),
  source: GameSourceType.chessCom,
  sourceUrl: 'https://www.chess.com/game/live/123',
  pgn: pgn,
  variant: Variant.standard,
  playedAt: DateTime.fromMillisecondsSinceEpoch(endTime * 1000),
  white: 'blancas', black: 'negras',
  whiteElo: 1650, blackElo: 1600,
  result: '1-0',
  timeControl: '600',
  opening: 'Sicilian Defense',
  eco: 'B20',
)
```

Reglas:

- Si el PGN trae `[FEN]` y `[SetUp "1"]`, respetar la posición inicial.
- Si la variante no es estándar, marcarla y avisar; el motor Fairy-Stockfish puede soportar algunas, pero el informe y las etiquetas deben probarse.
- Si faltan nombres o Elo, usar "Blancas"/"Negras" y `null`.
- Si el resultado no está, inferirlo del PGN o dejarlo vacío.
- Guardar el PGN original sin modificar.

## 5. Caché

- **Metadatos**: lista de partidas por usuario/fuente, TTL 12 h.
- **Partidas**: PGN completo, sin TTL (una partida terminada no cambia).
- **Informes**: por hash de configuración; invalidar si cambia el motor, la red NNUE, la profundidad, MultiPV o las reglas de clasificación.
- **ETag/Last-Modified** para Chess.com y Lichess.
- Limpiar caché desde ajustes; mostrar tamaño.

## 6. Errores y mensajes

| Caso | Mensaje |
|---|---|
| Usuario no existe | "No encontramos ese usuario en Lichess/Chess.com." |
| Sin partidas | "Ese usuario no tiene partidas públicas en el rango elegido." |
| 429 | "La plataforma pidió esperar. Reintentaremos en un minuto." |
| Sin conexión | "Sin conexión. Puedes abrir las partidas ya descargadas." |
| Partida privada | "Esta partida no es pública. Exporta el PGN y pégalo aquí." |
| Variante no soportada | "Esta variante aún no está soportada en el informe." |
| PGN inválido | "El PGN no es válido o está incompleto." |

## 7. Privacidad

- No subir partidas a servidores propios.
- No registrar tokens ni PGNs en logs.
- Guardar tokens en `flutter_secure_storage`.
- Chess.com no requiere token; Lichess sí para datos privados.
- El usuario puede borrar la biblioteca local y la caché.
- Política de privacidad clara antes de publicar.
