# Referencias de UX (observación en dispositivo)

Notas tomadas el 19 de noviembre de 2026 observando las apps instaladas de Chess.com y Lichess en un dispositivo Android real. Sirven para decidir nuestro propio flujo; **no** se copian pantallas, iconos, colores, nombres ni assets. Solo se describen patrones y problemas.

## Chess.com

Flujo observado: pestaña **Más** → **Perfil** → **Historial de partidas**.

- El historial muestra la **precisión** de cada partida como número destacado (p. ej. `72,7`). Eso crea una expectativa: el usuario ya sabe que existe una métrica antes de entrar en la revisión.
- Las partidas recientes tienen una acción de **revisión** separada del análisis normal del tablero (un botón verde con estrella en la fila de la partida). La revisión se presenta como un producto propio, no como "abrir el tablero".
- Al pulsar esa acción apareció un diálogo de **límite diario alcanzado** con el botón de suscripción Premium. El muro está exactamente en el momento de mayor intención del usuario.
- La app dedica espacio destacado en **Más** a promocionar Premium antes de cualquier opción de cuenta.

### Qué aprendemos

1. **Nuestra ventaja es jurídica y de producto**: aquí la revisión es ilimitada, local y gratis. Nunca debe aparecer un muro de pago ni un contador de revisiones.
2. Conviene que la precisión y las etiquetas aparezcan **después** de revisar, en el historial local de Chess Zerox. Mostrar números sin haberlos calculado sería engañoso.
3. La revisión merece **su propia entrada** junto al análisis, no escondida dentro del tablero. En nuestra app vive en la misma partida importada: analyze primero, y ofrecer "Revisar partida" como acción explícita.
4. No reutilizaremos el botón verde con estrella ni el resto de su lenguaje visual. Nuestra estrella es solo una etiqueta textual propia: **Jugada estrella**.

## Lichess

- La navegación inferior (Inicio, Ejercicios, Aprender, Ver, Más) es la misma base que ya heredamos del fork; no hay nada que rediseñar ahí.
- El tablero de análisis y el explorador de aperturas son fuertes, pero **no cuentan una historia**: dan evaluación y líneas, no una revisión guiada con errores explicados y práctica posterior.
- Esa es exactamente la capa original que queremos añadir, apoyándonos en su motor y en su parser de PGN.

## Decisiones para nuestra interfaz

- Textos propios en español: **Revisión de partida**, **Jugada estrella**, **Ocasión perdida**, **Informe de la partida**.
- La precisión se calcula en el dispositivo con Stockfish; si no se ha calculado, se muestra "Sin revisar", nunca un número prestado de la plataforma de origen.
- Cada etiqueta lleva una explicación corta y accionable. Las heurísticas (estrella, ocasión perdida) se presentan como orientativas, no como verdad absoluta.
- La revisión funciona sin conexión y sin cuenta, y se puede cancelar en cualquier momento.
- Importar y revisar son dos pasos distintos: importar → tablero de análisis → "Revisar partida" → informe → ejercicios.
