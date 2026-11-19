# Licencias, marcas y cumplimiento

> Esto es una guía práctica, no asesoría legal. Antes de publicar, revisa los términos actuales y, si hay dinero de por medio, consulta con un abogado.

## 1. La decisión que condiciona todo: GPLv3

Lichess Mobile es **GNU GPLv3**. Si haces un fork y distribuyes la app (APK, Play Store, F-Droid, GitHub Releases), debes:

1. Publicar el **código fuente completo** de tu versión, incluidas tus modificaciones.
2. Distribuirlo bajo **GPLv3** (o compatible), sin añadir restricciones.
3. Incluir la licencia, los avisos de copyright y las atribuciones.
4. Entregar el código por el mismo canal o con una oferta escrita válida.
5. No usar patentes, DRM o términos que impidan al usuario ejercer sus derechos GPL.

Esto no impide:

- Cobrar por el APK, por soporte o por servicios.
- Tener una marca propia.
- Publicar en Play Store (Google permite GPL; debes cumplir la licencia y las políticas).
- Pedir donaciones.

Sí impide:

- Mantener el código cerrado.
- Publicar una app con cambios privativos.
- Impedir que otros redistribuyan tu versión.

Si no aceptas esto, **no uses el fork de Lichess Mobile**. La alternativa sería construir desde cero con componentes permisivos, lo que multiplica el trabajo y pierde el motor, el tablero y la accesibilidad ya resueltos.

## 2. GPLv3 vs AGPLv3

- **Lichess Mobile (Flutter):** GPLv3. Es la base elegida.
- **Lila (servidor web de Lichess):** AGPLv3. Si reutilizas código de lila y lo sirves por red, la AGPL exige ofrecer el código a los usuarios del servicio. Para el MVP no necesitamos lila; solo la app móvil y las APIs.
- **Stockfish:** GPLv3. Compatible con la app.
- **Redes NNUE:** verifica la licencia de cada archivo que empaquetes o descargues. La app ya gestiona la descarga; conserva avisos y atribuciones.
- **Dependencias:** revisa que sean compatibles con GPLv3. Evita dependencias propietarias o con cláusulas que impidan redistribuir.

## 3. Marcas: Lichess y Chess.com

La licencia del código no te da derecho a usar sus marcas, logos, iconos, sonidos, piezas o diseño.

Debes cambiar:

- Nombre visible de la app.
- `applicationId` / bundle id (no `org.lichess.mobileV2`).
- Icono, splash, ilustraciones y sonidos.
- Deep links (`org.lichess.mobile://...`) por un esquema propio.
- Notificaciones, nombres de canales y textos que impliquen afiliación.
- Colores, glyphs y layout que copien los de Chess.com.

Puedes decir:

- "Compatible con Lichess y Chess.com".
- "Importa tus partidas de Lichess y Chess.com".
- "No afiliado a Lichess ni a Chess.com".

No puedes decir:

- "Lichess" o "Chess.com" como nombre de tu app.
- "Oficial", "partner" o "recomendado por" sin permiso.
- Que tu app es "Chess.com Analysis" o "Game Review".

### Nombres de funciones

Chess.com protege sus nombres y glyphs de clasificación. Para evitar problemas:

- No uses "Game Review"; usa "Revisión de partida" o "Informe".
- No uses "Brilliant"; usa "Jugada estrella" o "Sacrificio brillante" como descripción genérica.
- No copies los iconos de corona, brillante, libro, etc. Crea los tuyos.
- No copies la paleta exacta ni el layout pixel a pixel. Inspírate en la jerarquía visual, no en el asset.

## 4. Chess.com PubAPI

La ayuda oficial de Chess.com (actualizada en 2026) dice que la PubAPI puede usarse, incluso comercialmente, si:

- No abusas ni spameas a sus usuarios.
- No interrumpes su servicio.
- No copias sus funciones ni su propiedad intelectual.
- Indicas claramente que tu producto no está afiliado a Chess.com.

Además:

- Solo datos públicos; no partidas privadas.
- Peticiones seriales; sin paralelismo.
- `User-Agent` con contacto.
- Caché de 12 h y respeto de `ETag`/`Last-Modified`.
- Nada de endpoints internos ni scraping.
- Sus términos pueden cambiar; revisa la versión vigente antes de publicar.

Atribución sugerida en la app y en la ficha de la tienda:

> Datos de partidas proporcionados por la API pública de Chess.com. Este proyecto no está afiliado, patrocinado ni respaldado por Chess.com.

## 5. Lichess API

- `User-Agent` obligatorio con nombre de app y contacto.
- Una petición a la vez.
- Ante 429, esperar 60 segundos.
- No scraping.
- OAuth PKCE para datos privados.
- Cachear y no pedir más de lo necesario.
- Respetar los límites de exportación (20/30/60 partidas por segundo según el caso).

Atribución sugerida:

> Datos de partidas proporcionados por la API pública de Lichess. Este proyecto no está afiliado a Lichess.

Lichess es una organización sin ánimo de lucro; si el proyecto crece, considera donar o contribuir.

## 6. Stockfish y NNUE

- Stockfish es GPLv3. Incluye el texto de la licencia y la atribución.
- Si compilas una versión modificada de Stockfish, publica los cambios.
- Las redes NNUE tienen su propia licencia; verifica el archivo que descargas y no lo presentes como si fuera tuyo.
- No uses el nombre "Stockfish" para tu app; puedes decir "motor Stockfish" como hecho técnico.

## 7. Privacidad y Play Store

Antes de publicar:

- Política de privacidad accesible.
- Data safety form en Play Console.
- Declarar qué datos se recogen (idealmente: ninguno; todo local).
- Si hay analítica, que sea opt-in y esté explicada.
- Tokens en almacenamiento seguro; no en logs.
- Borrado de datos local desde ajustes.
- Permisos mínimos: internet, notificaciones (opcional), archivos (solo si el usuario importa).
- No pedir ubicación, contactos ni cámara si no es necesario.

## 8. Checklist antes de publicar

- [ ] Nombre y marca propios, sin "Lichess" ni "Chess.com".
- [ ] `applicationId` propio y deep links propios.
- [ ] Icono, splash, sonidos y assets originales o con licencia compatible.
- [ ] Sin copiar colores, glyphs ni layout exacto de Chess.com.
- [ ] `LICENSE`, `COPYING.md` y avisos de terceros incluidos.
- [ ] Código fuente de la versión publicada disponible.
- [ ] Enlace al código en la ficha de la tienda.
- [ ] Atribución a Lichess, Chess.com y Stockfish.
- [ ] "No afiliado" visible en la app y en la ficha.
- [ ] Política de privacidad.
- [ ] Data safety form.
- [ ] Revisión de los términos vigentes de Lichess y Chess.com.
- [ ] Tests de importación y de análisis en un dispositivo real.
- [ ] Plan de respuesta a DMCA/takedown y a cambios de API.

## 9. Si quieres monetizar

Opciones compatibles con GPLv3:

- Donaciones (GitHub Sponsors, Ko-fi, etc.).
- Venta del APK en una tienda; el código sigue libre.
- Soporte, formación o análisis personalizados.
- Servicios opcionales de sincronización en la nube (si el código del cliente sigue siendo GPL y el servicio no impone restricciones al software libre).

Opciones problemáticas:

- App cerrada con partes propietarias.
- Bloquear funciones que el código permite.
- DRM que impide modificar o redistribuir.
- Usar datos de Chess.com para entrenar modelos sin permiso.

La marca y la confianza pueden ser el negocio; el código no necesita serlo.
