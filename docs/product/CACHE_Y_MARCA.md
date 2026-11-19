# Caché local, importación incremental y marca

## Identidad y alcance

Chess Zerox es una **tercera app**, no un reemplazo de Lichess ni de Chess.com:

- No se juega online ni contra el ordenador. Para eso están las apps originales.
- No hace falta cuenta: se consultan solo APIs públicas y documentadas.
- El eje es importar → analizar → revisar → practicar, con Stockfish en el dispositivo.
- Leemos las otras plataformas sin pelear con ellas: cabecera `User-Agent` identificable, petición
  en serie, caché y revalidación con `ETag`/`Last-Modified`.

### Cambio de nombre por fases

1. **Ya hecho**: etiqueta visible de Android (`Chess Zerox`) y textos propios en español.
2. **Pendiente, sin tocar aún**: `applicationId`, icono, splash, deep links y OAuth. Cambiar el id
   rompe `google-services.json` y el cliente OAuth de Lichess; como el MVP no necesita login, lo
   habitual será crear un proyecto Firebase propio (o quitar Firebase) y registrar un cliente OAuth
   propio solo si más adelante queremos partidas privadas.
3. Hasta entonces el APK debug se instala como `org.lichess.mobileV2.debug` y convive con la app
   original de Lichess.

## Caché de partidas importadas

### Tablas nuevas (sqflite, local)

```text
import_sources(
  source TEXT,             -- 'lichess' | 'chessCom'
  username TEXT,
  last_played_at INTEGER,  -- epoch ms de la partida más reciente ya guardada
  last_sync_at INTEGER,
  PRIMARY KEY (source, username)
)

imported_games(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source TEXT,
  external_id TEXT,        -- id de Lichess / uuid de Chess.com
  played_at INTEGER,
  white TEXT, black TEXT, result TEXT, speed TEXT,
  pgn TEXT NOT NULL,
  imported_at INTEGER,
  UNIQUE (source, external_id)
)
```

- Guardamos el **PGN completo** al importar: la revisión y el análisis funcionan después sin red.
- Guardamos el **nombre de usuario** por fuente para no volver a escribirlo. Se podrá borrar desde
  un ajuste «Datos de importación».
- El puntero es `last_played_at`, la fecha de la partida más nueva ya importada. No es un simple
  contador: si una partida se importó fuera de orden, el `MAX(played_at)` de la tabla manda.

### Flujo incremental

1. El usuario pulsa **Buscar partidas** (o «Actualizar»).
2. Se lee el cursor de `import_sources` para esa fuente y usuario.
3. Solo se piden partidas posteriores al cursor:
   - **Lichess**: `GET /api/games/user/{username}?since=<epochMs>&max=<n>&pgnInJson=true`.
   - **Chess.com**: se calcula el mes del cursor y se recorren los archivos mensuales desde ese mes;
     se descartan partidas con `end_time <= cursor`. Se respeta la caché de 12 h por archivo.
4. Se insertan las nuevas ignorando duplicados por `(source, external_id)`.
5. Se actualiza el cursor con `MAX(end_time/createdAt)` de lo recién guardado.
6. La UI muestra cuántas partidas son nuevas. Si no hay ninguna: «No hay partidas nuevas».

### Cantidad a importar

- Por defecto **30 partidas por fuente y sincronización**; el usuario podrá elegir 10/30/100.
- Chess.com sigue limitado a un número máximo de archivos mensuales por búsqueda (hoy 6) y se
  detiene en cuanto encuentra suficientes partidas nuevas.
- El primer uso trae las 30 más recientes; los siguientes solo traen lo posterior al cursor. No se
  vuelve a descargar el historial completo.

### Privacidad y límites

- Todo se guarda en el dispositivo; no hay backend ni sincronización en la nube en el MVP.
- Las partidas privadas de Chess.com no están en la PubAPI: se exporta el PGN y se pega.
- Las peticiones siguen siendo seriales y con `User-Agent` propio; el cursor reduce el tráfico
  todavía más.

## Próximo trabajo

1. Migración sqflite y repositorio `ImportedGameStore` con tests (sin red).
2. Conectar `UsernameImportScreen` al almacén: listar lo guardado, mostrar «N partidas nuevas» y
   botón de actualización.
3. Ajustes para borrar usuarios/partidas guardadas y elegir el número de partidas.
4. Solo después: rebrand técnico completo y decisión sobre Firebase/OAuth.
