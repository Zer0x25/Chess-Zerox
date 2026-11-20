# Idea futura: sacrificios destacados

Pendiente de investigación; no es una funcionalidad implementada ni una promesa de equivalencia
con Chess.com. Su documentación describe una jugada brillante como un buen sacrificio, entre otras
condiciones, pero no publica todos los detalles de su algoritmo.

Chess Zerox usa clasificaciones locales propias. La «Jugada estrella» actual no detecta sacrificios
y su condición basada en un gran salto de evaluación antes y después de la mejor jugada puede ser
demasiado restrictiva. Hay que medirla con posiciones reales antes de considerarla fiable.

Explorar una etiqueta propia como «Sacrificio destacado»:

- Detectar si se ofrece material y diferenciar una entrega real de un intercambio ordinario.
- Comprobar con el motor que la jugada es fuerte y que la compensación se sostiene en variantes.
- Comparar alternativas y estudiar la profundidad necesaria, sin prometer coincidencia con otro
  producto ni inventar explicaciones tácticas.
- Evaluar ejemplos de sacrificios correctos e incorrectos, capturas forzadas, mates y sacrificios
  temporales, además de falsos positivos y el coste en batería y tiempo.
- Mostrarlo como estimación local; definir cómo actualizar las revisiones ya guardadas si cambian
  las reglas de clasificación.

Referencia: https://support.chess.com/en/articles/8572705-how-are-moves-classified-what-is-a-blunder-or-brilliant-etc
