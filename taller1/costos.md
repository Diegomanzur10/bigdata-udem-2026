# Costos · Taller 1

Equipo: Valentina Restrepo Arboleda y Andres Fernando Molina Orozco · Cuenta que reporta (anfitrión): Valentina Restrepo Arboleda (usuario `valrestrepo209`)

## Créditos usados

> Medición en la cuenta del anfitrión, con rol `ACCOUNTADMIN` y warehouse `COMPUTE_WH`. Las mediciones cubren los tres días en que se trabajó en el taller.

**Rol:** `ACCOUNTADMIN`.

**Cómo se obtuvieron los valores.** La consulta devuelve consumo acumulado desde una fecha hasta el momento de ejecución, así que cada tramo debe calcularse por diferencia:

- Desde el 14 de noviembre: 1.8501.
- Desde el 15 de noviembre: 0.9513. Por diferencia, el 14 consumió 1.8501 − 0.9513 = 0.8988.
- Desde el 19 de noviembre: 0.3090. Por diferencia, el 15 consumió 0.9513 − 0.3090 = 0.6423.

| Día medido | Warehouse | Tamaño | Créditos |
|---|---|---|---|
| 2026-11-14 | COMPUTE_WH | XS | 0.8988 |
| 2026-11-15 | COMPUTE_WH | XS | 0.6423 |
| 2026-11-19 | COMPUTE_WH | XS | 0.3090 |
| **Total** | | | **1.8501** |

**Referencia de presupuesto (estimación del pensum, no medida):** hasta 0.3 créditos para el Lab 4 y hasta 0.8 para el taller en clase. El consumo medido de 1.8501 supera la referencia créditos. Podemos identificar dos posibles causas del aumento:

- **Iteraciones fuera de clase.** La carga completa de los datos del LAB 4 (`INSERT INTO FACT_VIAJES_DIA`, `CREATE OR REPLACE TABLE DIM_EMPRESA`) y los chequeos (`SELECT 'filas' ...`) fueron ejecutados varias veces los días 14 y 15. 
- **Vistas recalculadas.** La consulta más pesada recalcula zona × día en cada ejecución.

## Consulta más pesada

- **Consulta:** la variante por zona de la pregunta B2 (`WITH con_ayer AS (...)` sobre `CURSO.T1.VW_DIARIO_ZONA`), que calcula con `LAG` los saltos de viajes de más de 50 % frente al día anterior en cada zona. Pertenece al Caso B, pregunta B2, dentro del reto R1 (`05_retos.sql`). Esta fue una de las consultas que se implementó durante el desarrollo del reto, sin embargo no fue la consulta final propuesta.
- **ID:** `01c886dc-0209-f78a-0012-c5fa000e70c6`.
- **Cómo la encontramos:** Snowsight > Monitoring > Query History, filtrado por el usuario `valrestrepo209` y ordenado por duración descendente. Es la consulta de mayor duración del listado: 9.1 s.
- **Desglose del tiempo según el historial:** 533 ms de compilación, 8.2 s de espera de aprovisionamiento y 343 ms de ejecución. La duración se explica sobre todo por el arranque del warehouse, no por el cálculo.
- **Captura del Query Profile:** `query_profile.png` [`query_profile.png`](query_profile.png). Muestra el perfil de esta misma consulta, con un tiempo total de 8.8 s.

## Lectura del Query Profile

- **Operador que concentra el tiempo:** dos `TableScan` de `CURSO.T1.FACT_VIAJES_DIA`, los más caros del perfil, con 25 % cada uno (50 % juntos). El perfil marca además dos agregaciones como `Inefficient aggregate` (nodos 4 y 7). El tiempo se reparte en 50 % de lectura remota de disco y 50 % de inicialización.
- **Por qué pasa:** la vista `VW_DIARIO_ZONA` se recalcula en cada consulta (cruce zona × día con `LEFT JOIN` a la tabla de hechos), por eso el plan lee la tabla de hechos dos veces.
- **Qué haría para reducirlo:** Implementamos una forma diferente en la consulta empleando directamente las tablas sin requerir la vista, y redireccionando la consulta.

## Warehouse

- **Tamaño:** X-Small.
- **Suspensión automática:** Ejecutamos esta consulta `SHOW WAREHOUSES` para validar en la columna `auto_suspend` el tiempo, el cual fue de 60 segundos.
- **Al terminar:** no lo suspendimos manualmente. Solo fue a través de suspensión automática.
