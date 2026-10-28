# Panel de Impulso Creativo — cómo retomar

El sistema interno de la agencia (Mati, Anni y Agus): consultas y clientes, presupuestos, trabajos por
línea, acreditaciones, gastos, cobros, horas y un tablero de rentabilidad. Reemplaza a la planilla
«Impulso — Libro de eventos» (id `1UAgRSFCNiWiOFhVuL44ud8oH9dMGKjgAtC7zfZtXtg8`).

## Leer en este orden

1. `ESTADO.md`: en qué sesión y etapa estamos, y qué sigue.
2. `DECISIONES.md`: lo que se decidió y por qué.
3. La propuesta: `H:\Mi unidad\Desarrollo\Impulso\8 - Panel de Impulso - propuesta de diseno.pdf`
   (y el Doc https://claude.ai/artifact/VnWzmbJDH9CoZTXqWmFXHu).
4. Specs de base: los PDF de `H:\Mi unidad\Desarrollo\Impulso\`, sobre todo «7 - El panel de la empresa».

## Resguardos (reemplazan a la regla de parada del libro)

- Repo, carpeta y base propios. De AXSION (`C:\AXSION`) y CEPATAGONIA (`C:\Mati\Trabajo\Repos\cepatagonia-*`)
  se copia código; nunca datos ni bases. Esas carpetas solo se leen.
- Cada etapa termina en algo usable y tiene tope de sesiones. Si se pasa, se frena y decide Mati.
- Nada de módulos «por si acaso».

## Reglas que no se negocian

- Las tres decisiones del libro: vacío = «no se puede saber», nunca cero; el id del trabajo nace en la
  consulta y no cambia; todo peso con el índice de su mes. Las controla la base y las vigilan las pruebas.
- Velocidad: cada tarea diaria al menos tan rápida como en la planilla, medida con pruebas calibradas
  contra una PC de oficina lenta y un celular de gama media (el arnés de AXSION). Nunca con la notebook sin freno.
- Siempre con pruebas automáticas: sin verde no se cierra nada (`npm test`).
- Nunca datos reales en pruebas ni ejemplos: todo ficticio.
- Celular primero.
- Código en `impulsocreativo-ba/impulso-panel` (privado). Documentos en `H:\Mi unidad\Desarrollo\Impulso`.
- Hablarle a Mati en rioplatense, con voseo. Lo que va al cliente, en primera persona y sin emojis.

## Cómo se prueba

`npm install` una vez y después `npm test`. Las pruebas de base cargan `db/migraciones/*.sql` en PGlite
(Postgres en Node, sin Docker), en orden.
