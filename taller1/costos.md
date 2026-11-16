# Costos · Taller 1

Equipo: Valentina Restrepo Arboleda y Andres Fernando Molina Orozco · Cuenta que reporta (anfitrión): Valentina Restrepo Arboleda (usuario `valrestrepo209`)

## Créditos usados

Medición en la cuenta del anfitrión, con rol ACCOUNTADMIN y warehouse COMPUTE_WH (X-Small).

| Día medido | Warehouse | Tamaño | Créditos |
|---|---|---|---|
| 2026-11-14 | COMPUTE_WH | XS | 0.8988 |
| 2026-11-15 | COMPUTE_WH | XS | 0.5331 |
| **Total** | | | **1.4319** |

El consumo del 14 se obtuvo restando el del 15 al total desde el 14 (1.4319 − 0.5331). La consulta por día confirma ambos valores:

```sql
SELECT START_TIME::DATE AS DIA,
       WAREHOUSE_NAME,
       ROUND(SUM(CREDITS_USED), 4) AS CREDITOS
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(
       DATE_RANGE_START => '2026-11-14'::DATE,
       DATE_RANGE_END   => '2026-11-15'::DATE,
       WAREHOUSE_NAME   => 'COMPUTE_WH'))
GROUP BY 1, 2
ORDER BY 1;
```

Referencia de presupuesto (estimación del pensum, no medida): hasta 0.3 créditos el Lab 4 y hasta 0.8 el taller en clase. El consumo medido (1.4319) supera la referencia propuesta en el taller. Esto se debe a que se realizaron varias consultas y ejecuciones repetidas de los chequeos (`SELECT 'filas' ...`) y de la carga (`INSERT INTO FACT_VIAJES_DIA`, `CREATE OR REPLACE TABLE DIM_EMPRESA`) durante el desarrollo.

## Consulta más pesada

- Consulta: la generación de días de `DIM_FECHA` (`WITH r AS ... dias AS ...`), que alimenta el `INSERT INTO DIM_FECHA` de `02_carga.sql`. Pertenece a la carga de la estrella, no a las preguntas resueltas del caso A.
- ID de la consulta: `01c86a80-0109-d9e2-0012-c5fa0009a3a2`.
- Cómo la encontré: Snowsight > Monitoring > Query History, filtrada por usuario y ordenada por duración descendente. Es la de mayor duración del listado.
- Tiempos: 2.9 s en total, que se descomponen en 1.3 s de compilación, 1.3 s de aprovisionamiento en cola y 192 ms de ejecución.
- Tiempo de ejecución según el Query Profile: 1.9 s.
- Datos leídos: unas 46.7 mil filas de `CURSO.LAB4.DAILY_ZONE_METRICS` pasan por el filtro; se escanearon 0.13 MB, 2 de 2 particiones, sin uso de caché.
- Qué hace: calcula el rango de fechas con `MIN` y `MAX` sobre el gold, genera un día por fila con `GENERATOR` y `ROW_NUMBER`, marca los festivos con `LEFT JOIN` a `FESTIVOS_2024` y toma la lluvia del día con `MAX` agrupado por `FECHA`.
- Captura del Query Profile: `query_profile.png` (en esta carpeta).

## Lectura del Query Profile

- Operador que concentra el tiempo: `TableScan [7]` sobre `CURSO.LAB4.DAILY_ZONE_METRICS`, con 33.3 % del tiempo. El 66.7 % restante es inicialización.
- Lectura: la consulta es pequeña. La mayor parte del tiempo es el arranque del warehouse y la lectura de una tabla de 46 715 filas. En XS no hay un cuello de botella real.
- Qué haría para reducirlo: la tabla `DAILY_ZONE_METRICS` se lee dos veces en esta consulta, una para el `MIN`/`MAX` y otra para la lluvia diaria. Lo ideal sería  fijar el rango en 2024-01-01 a 2024-03-31, que es lo que define el enunciado, y calcular la lluvia en la misma lectura. La reducción sería pequeña, porque el total ya es de 1.9 s.

## Warehouse

- Tamaño: X-Small.
- Al terminar: no se suspende manualmente. Queda inactivo y se suspende solo tras el tiempo de inactividad, así que no consume créditos mientras no ejecuta consultas.
