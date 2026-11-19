# Plan de producto y roadmap

## 1. Problema y oportunidad

Un jugador de club quiere saber **por qué** perdió y **qué** practicar. Hoy tiene dos caminos:

- **Lichess**: análisis gratis y fuerte, pero más orientado a explorar que a dar una revisión guiada; sus partidas viven en Lichess.
- **Chess.com**: muy buena experiencia de revisión, pero la revisión completa es de pago y sus partidas viven en Chess.com.

Nadie une las dos bibliotecas, y casi nadie convierte los errores en un plan de entrenamiento duradero. Ahí está el hueco: no ser otra plataforma de ajedrez, sino **el analizador y entrenador personal que importa tus partidas de donde sea y te explica cómo mejorar**.

## 2. Principios de producto

1. **No reinventar el ajedrez.** Tablero, reglas, PGN y motor salen de Lichess/Stockfish.
2. **No competir con las plataformas.** Somos un cliente de análisis, no un sitio de juego.
3. **Análisis local primero.** Privacidad, offline y coste cero. La nube es opcional.
4. **Enseñar, no solo puntuar.** Cada error debe tener una explicación y una acción.
5. **No copiar a Chess.com.** Inspiración funcional sí; nombres, colores, iconos, glyphs, sonidos y assets no.
6. **Gratis de verdad.** Sin muro de pago para el análisis. Donaciones o servicios opcionales, nunca el núcleo.
7. **Open source y GPLv3.** Es la condición para usar la base de Lichess y una ventaja de confianza.

## 3. Usuarios

### Persona A: jugador de Chess.com (1200-1800 Elo)

Juega 5-10 partidas rápidas por semana. Quiere saber en qué falló sin pagar la suscripción. Le da pereza exportar PGN.

**Necesita:** conectar su usuario, elegir una partida reciente, ver un informe claro y practicar el error principal.

### Persona B: jugador de Lichess (1500-2100 Elo)

Ya usa el análisis de Lichess, pero quiere una revisión más guiada y llevar sus errores de varias partidas.

**Necesita:** importar su historial, análisis offline y un cuaderno de errores.

### Persona C: estudiante sin cuenta

Recibe PGNs de su entrenador o ve una partida en un vídeo.

**Necesita:** pegar un PGN, analizarlo y compartir el informe.

## 4. Flujo principal

```text
Inicio
  └─ Importar partida
       ├─ Lichess (usuario o URL)
       ├─ Chess.com (usuario; PGN si es privada)
       ├─ PGN / FEN
       └─ Compartir desde otra app
            ↓
       Lista de partidas / vista previa
            ↓
       Revisar partida
         - Elegir profundidad: rápida, equilibrada, profunda
         - Progreso y cancelación
            ↓
       Informe
         - Precisión y ACPL
         - Gráfico de evaluación
         - Clasificación de jugadas
         - Momentos clave
         - Explicación del entrenador
            ↓
       Entrenar errores
         - Repetir la posición
         - Jugar la mejor jugada
         - Feedback y repaso espaciado
```

## 5. Alcance funcional del MVP

### 5.1 Importación

- **Lichess**
  - Por nombre de usuario, sin login, para partidas públicas.
  - Login OAuth PKCE opcional para partidas privadas, favoritas y en curso.
  - Por URL de partida (`lichess.org/{id}`) y por PGN.
- **Chess.com**
  - Por nombre de usuario usando la Published-Data API.
  - Selección de mes/año y filtro por ritmo.
  - Por PGN para partidas privadas o no accesibles.
  - Sin login: la API pública no expone partidas privadas.
- **PGN/FEN/compartir**
  - Pegar, elegir archivo o recibir un `ACTION_SEND`.
  - PGN con múltiples partidas: lista para elegir.
  - Detección de variantes y posición inicial.

### 5.2 Revisión

- Motor local Stockfish 18 NNUE.
- Tres modos:
  - **Rápida**: profundidad 14, MultiPV 1 y segunda pasada en errores. Para partidas de 10+0.
  - **Equilibrada**: profundidad 16-18, MultiPV 2 en posiciones críticas. Recomendado.
  - **Profunda**: profundidad 20-22, MultiPV 3 en posiciones críticas. Requiere paciencia y cargador.
- Progreso por jugada, tiempo restante estimado, cancelar y reanudar.
- Caché por PGN + motor + red + configuración.
- Si la partida es de Lichess y ya tiene análisis de servidor, se puede reutilizar para acelerar; el informe local sigue siendo el que manda para la clasificación.

### 5.3 Informe

- Precisión de ambos jugadores.
- ACPL (pérdida media de centipeones) y desglose por fase.
- Gráfico de evaluación interactivo.
- Conteo de clasificaciones por jugador.
- Lista de movimientos con etiqueta, evaluación y mejor alternativa.
- Momentos clave priorizados: errores graves, ocasiones perdidas, sacrificios, única jugada.
- Explicación en español, generada a partir de hechos de la posición y la línea del motor. Sin LLM en el MVP.
- Enlace para compartir el informe como imagen o PGN anotado.

### 5.4 Entrenamiento

- "Repite este error": se coloca la posición antes del error, el usuario juega y el motor comprueba.
- "Errores de la partida": lista de ejercicios.
- "Mi cuaderno de errores": base local de posiciones falladas, con repaso espaciado (SM-2 simplificado).
- Estadísticas: errores por tipo, por fase, por apertura, evolución.

## 6. No objetivos

- Jugar partidas online o crear torneos.
- Clonar la interfaz, los iconos, la paleta, los sonidos o los nombres de Chess.com.
- Usar endpoints internos, scraping o automatización de las webs.
- Prometer "el análisis más fuerte del mundo". El motor es el mismo que ya usan otros; la ventaja es la experiencia de aprendizaje.
- Análisis en servidor propio en el MVP.
- Detección de trampas.

## 7. Roadmap

Las duraciones suponen un desarrollador con experiencia en Flutter trabajando a tiempo parcial. Si estás aprendiendo Flutter, multiplica por 1,5-2.

**Estado (noviembre de 2026):** fase 0 parcial (fork, nombre visible y tests; faltan
`applicationId`, iconos, splash, deep links y compilar el APK) y fase 1 parcial (importación por
usuario de Lichess y Chess.com, PGN, normalización y apertura en el tablero; faltan URL directa y
biblioteca local). El resto sigue pendiente.

### Fase 0 — Base y legal (semana 1)

- Confirmar GPLv3 y código público.
- Elegir nombre y marca; revisar que no choque con marcas existentes.
- Fork de `lichess-org/mobile`.
- Cambiar `applicationId`, nombre visible, icono, splash y deep links.
- Instalar Flutter 3.50 y Android SDK; compilar y ejecutar.
- CI con `flutter analyze` y `flutter test`.
- Página de atribuciones y política de privacidad.

**Criterio de aceptación:** APK de debug con marca propia que abre el tablero y analiza una posición.

### Fase 1 — Importación (semanas 2-3)

- Pantalla "Importar partida" con las cuatro fuentes.
- Cliente de Chess.com con User-Agent, peticiones seriales, caché y ETag.
- Reutilizar el cliente de Lichess existente; añadir URL y PGN.
- Normalizador de partidas y biblioteca local.
- Manejo de errores y atribución.

**Criterio de aceptación:** importar las últimas 20 partidas de un usuario de Lichess y de uno de Chess.com, abrirlas y verlas en el tablero.

### Fase 2 — Núcleo de revisión (semanas 4-6)

- Modelo `GameReview`, `MoveReview`, `MoveTag`, `AccuracyReport`.
- Orquestador de evaluación por lotes con progreso y cancelación.
- Fórmulas de Win% y accuracy de Lichess.
- Clasificación y detección de momentos clave.
- Tests unitarios con evaluaciones simuladas.
- Comando de depuración que imprime el informe en JSON.

**Criterio de aceptación:** un PGN de 40 jugadas genera un informe coherente y reproducible en menos de 3 minutos en un móvil de gama media con el modo equilibrado.

### Fase 3 — Informe visual (semanas 7-9)

- Pantalla de informe con resumen, gráfico, lista y momentos clave.
- Barra de evaluación y flecha de mejor jugada en el tablero.
- Integración con el análisis existente (saltar a una jugada, explorar variantes).
- Diseño original, tema oscuro, accesibilidad y modo claro.
- Textos en español e inglés.

**Criterio de aceptación:** el informe se entiende sin leer documentación; se puede navegar con el dedo y con lector de pantalla.

### Fase 4 — Entrenamiento y pulido (semanas 10-11)

- Ejercicios a partir de errores y repaso espaciado.
- Caché de informes y modo offline.
- Servicio en primer plano para revisiones largas.
- Ajustes de rendimiento y batería.
- Analítica opcional y respetuosa (off por defecto).

**Criterio de aceptación:** cerrar la app y volver a abrir un informe cacheado sin recalcular; completar un ejercicio de error.

### Fase 5 — Beta y publicación (semana 12)

- Beta cerrada con 10-20 usuarios.
- Corrección de los 10 errores más reportados.
- F-Droid y GitHub Releases; Play Store si se cumplen requisitos.
- Publicar código fuente, licencia, avisos y política de privacidad.
- Manual de uso y vídeo corto.

**Criterio de aceptación:** instalación limpia desde F-Droid/GitHub, revisión de una partida real y código fuente disponible.

## 8. Estimación

- **MVP funcional (fases 0-4):** 180-280 horas.
- **Beta publicable (fase 5):** 30-50 horas más.
- **Ritmo:** 8-12 semanas a tiempo parcial; 5-7 semanas a tiempo completo con experiencia previa en Flutter.
- **Riesgo principal de tiempo:** la interfaz de informe y la afinación de la clasificación, no el motor.

## 9. Métricas

- Tiempo hasta el primer informe.
- Porcentaje de informes completados sin cancelar.
- Errores por partida y errores practicados.
- Retención a 7 y 30 días.
- Relación entre precisión local y análisis de servidor de Lichess en una muestra de 100 partidas.
- Crash-free sessions.
- Feedback cualitativo: "¿Entendiste por qué falló?".

Sin telemetría por defecto. Si se añade, debe ser opt-in y explicada.

## 10. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| GPLv3 exige publicar el código | Alto si querías cerrarlo | Decidirlo antes de escribir código; ver `docs/product/LEGAL.md` |
| Copiar la marca/diseño de Chess.com | Legal y reputacional | Diseño original; evitar sus nombres y glyphs |
| La API de Chess.com cambia o limita | Importación rota | Adaptador aislado, caché, PGN manual, tests con fixtures |
| Móviles lentos o calientes | Mala experiencia | Modos de profundidad, 1 hilo, límite por posición, progreso |
| Expectativa de "igual que Chess.com" | Decepción | Comunicar que la fuerza es similar; la diferencia es enseñanza |
| Scope creep (jugar online, torneos) | Retraso | No objetivos escritos y revisados |
| Clasificación subjetiva (brillante, única) | Controversia | Etiquetas propias, heurísticas explicadas y configurables |

## 11. Decisiones pendientes

1. ¿Aceptas GPLv3 y publicar el código? Sin esto no se puede usar el fork de Lichess Mobile.
2. ¿Nombre definitivo? "Chess Zerox" es provisional; "Zerox" puede evocar Xerox.
3. ¿Monetización? Donaciones, servicios opcionales o venta del APK (GPL lo permite, pero el código sigue siendo libre).
4. ¿Publicar en Play Store, F-Droid, GitHub o las tres?
5. ¿Contribuir mejoras genéricas a Lichess Mobile o mantener un fork con diferencias de producto?
