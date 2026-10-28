# Decisiones del panel

Las tomó Claude **en rol de socio de Impulso** el 28/10/2026, a pedido de Mati («decidí vos en rol»).
Son provisorias hasta que Mati las repase. Cada una dice qué cambia si se da vuelta.

| # | Pregunta | Decisión | Por qué | Si se cambia |
|---|---|---|---|---|
| 1 | Índice: ¿MEP o IPC? | **Dólar MEP, promedio de cierres del mes, de una sola fuente** (la misma que usa AXSION: Ámbito). Se carga a mano el día 1 de cada mes en `indices`. | Se cotiza en dólares y el MEP se conoce todos los días; el IPC sale a mitad del mes siguiente y el mes en curso diría «no se puede saber» dos semanas. | Cambia `a_constante()` y se recarga `indices`. Lo congelado en CIERRES no se toca. |
| 2 | Precio de acreditación | **El de «La oferta»: fijo por puerta y jornada + un monto por persona habilitada**, con el mínimo de una puerta y una jornada. El 3% de lo facturado queda solo como control de que el número cierra. Pisos de «El plan»: nunca menos de USD 1,50 por acreditado. | Es el documento más nuevo (17/10) y el que lee el cliente; no le pide al cliente mostrar cuánto vendió. | Es un dato del tarifario (etapa 2), no del esquema. |
| 3 | Agus | **Socio, con los mismos permisos que Mati y Anni.** Su línea queda sin asignar hasta que Mati diga qué hace. | No hay dato; dar menos acceso a un socio es peor error que dar el mismo. | Se cambia su rol en Accesos. |
| 4 | Quién factura | **Factura Mati (monotributo, Factura C).** Cada cobro guarda `facturo` (la persona), así que otro socio puede facturar sin cambiar el esquema. | Es lo que dice la memoria del presupuesto del estudio jurídico. | Nada en la base; cambia el texto del PDF. |
| 5 | Permisos entre socios | **Los tres ven todo**, márgenes y horas de los otros incluidos. | Tres socios que deciden juntos qué aceptar necesitan los mismos números. | Se agrega un rol en Accesos (etapa 1, sesión de permisos). |
| 6 | Cuenta corriente entre socios | **Sí, lo mínimo:** cada gasto guarda `pagado_por`. El tablero suma lo que puso cada uno. Retiros y sueldos quedan afuera. | Con tres socios pagando de su bolsillo, se pierde rápido y genera discusiones. Cuesta una columna. | Si no la quieren, se oculta la suma; el dato no molesta. |
| 7 | Contenido (Anni) | **En el panel va la plata y las horas de contenido, no la producción.** Las entregas, aprobaciones y calendarios siguen en las herramientas de Anni. | Regla «nada por si acaso»: nadie pidió mover la producción. | Sería un módulo nuevo, con su propia etapa. |
| 8 | Horas | **Una fila por persona y por fase, marcada como estimada.** Se puede cargar al cerrar o por semana: es la misma tabla (`semana` es opcional). | Es lo que dice el libro; la carga semanal no cuesta nada extra. | Nada. |
| 9 | Mail | **Botón que abre el correo de cada uno con el mensaje armado** hasta que ande `hola@` en Zoho. | No depende de nada que no exista. | Se cambia el botón por el envío desde Zoho (etapa 5). |
| 10 | Moneda | **Cada importe guarda su moneda (ARS o USD).** Web y contenido se cotizan en pesos; acreditaciones también en pesos, como «La oferta». El tablero lo lleva todo a dólares MEP. | Ninguna línea queda forzada; el índice hace comparable todo. | Nada. |
| 11 | Cuándo | **La etapa 1 arranca ahora, solo con lo que no necesita cuentas** (esquema, pruebas, pantallas contra una base local). AXSION tiene prioridad en el uso de Claude hasta la demo del 16/11: si el uso semanal pasa el 80%, el panel espera. | Es el frente sin fecha; AXSION es el frente con fecha. | — |
| 12 | ¿Se cargó algo en el Libro después del 27/10? | **No lo puedo decidir.** El importador lo va a mostrar al traer la planilla. | — | — |

## Decisiones de esquema tomadas en la sesión 1

- **ESTRUCTURA** no es un trabajo: gastos y horas llevan `trabajo_id` **o** `es_estructura = true`, nunca las dos ni ninguna. Un `trabajo_id` vacío no puede significar «estructura», porque vacío significa «no se puede saber».
- **Los trabajos no se borran.** Lo que no salió pasa a `perdido` o `caido` con su motivo. La base rechaza el borrado.
- **La moneda constante es el dólar MEP del mes.** Un importe en pesos se divide por el índice de su mes; uno en dólares queda igual. Para mostrarlo en pesos de hoy se multiplica por el índice del mes corriente.
- **El ingreso de un trabajo, por ahora, es la suma de sus cobros** (lo facturado). Para un trabajo propio el ingreso real sale de CIERRES; eso entra en la etapa 3.
- **Transiciones permitidas:** consulta → presupuestado, firmado o perdido; presupuestado → firmado o perdido; perdido → presupuestado (vuelve); firmado → cerrado o caido. `cerrado` y `caido` son finales.
