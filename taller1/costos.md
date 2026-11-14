# Costos · Taller 1

**Equipo:** Natasha, Miguel Ángel, Xiomi
**Cuenta que reporta (anfitrión):** Miguel Ángel Vélez

## Costo en dólares

El costo total del equipo fue de **6 USD**, distribuidos así:

| Integrante   | Costo (USD) |
|--------------|-------------|
| Natasha      | 3           |
| Miguel Ángel | 3           |
| Xiomi        | 0           |
| **Total**    | **6**       |

Miguel Ángel tuvo cobros adicionales al terminar el taller, por lo que su monto subió respecto a la estimación inicial.

## Créditos usados

Resultado de la consulta ejecutada en la cuenta anfitriona:

```sql
SELECT ROUND(SUM(CREDITS_USED), 4) AS CREDITOS
FROM TABLE(INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(
       DATE_RANGE_START => '2026-11-10'::DATE,
       WAREHOUSE_NAME => 'COMPUTE_WH'));
```

| Medición desde | Warehouse  | Tamaño | Créditos          |
|----------------|------------|--------|-------------------|
| 10/11/2026     | COMPUTE_WH | XS     | [6] |

Referencia de presupuesto (estimación del pensum, no medida): hasta 0.3 créditos el Lab 4 y hasta 0.8 el taller en clase.

## Consulta más pesada

- **Consulta:** bloque de controles del núcleo de `04_chequeos.sql` (sección A, sección 15 del README).
- **Cómo la encontraste:** Snowsight > Monitoring > Query History > ordenar por duración.
- **Duración:** 5.8 s, estado Success, warehouse COMPUTE_WH de tamaño X-Small, iniciada el 14/11/2026 a las 10:39:34.
- **Captura del Query Profile:** `query_profile.png` (en esta carpeta).

## Lectura del Query Profile

- **Operador que concentra el tiempo:** `TableScan [70]` sobre `CURSO.LAB4.DAILY_ZONE_METRICS`, con el **7.3 %** del tiempo. Es el único operador con porcentaje asignado; el resto de los nodos muestra 0 %.
- **Detalle del operador:** lee solo una columna (`ZONA`, de 8 disponibles) en una partición, con 0.36 MB escaneados y 100 % de progreso de escaneo.
- **Reparto general:** el perfil muestra 75 % de sincronización y 25 % de lectura remota de disco. El 7.3 % del escaneo no explica por sí solo el tiempo total de 5.8 s; el resto se atribuye a coordinación interna de Snowflake, que Snowsight no asigna a un operador concreto.
- **Qué haría para reducirlo:** el `TableScan` aparece porque la consulta calcula `COUNT(DISTINCT ZONA)` sobre `DAILY_ZONE_METRICS` en un control, y esa lectura se repite en otros controles. Si se calcula una sola vez, por ejemplo en un CTE con la lista de zonas, la consulta lee la tabla una vez en lugar de varias. El ahorro sería pequeño porque la tabla es pequeña; la decisión tiene sentido sobre todo como buena práctica.

## Warehouse

El warehouse `COMPUTE_WH` usó tamaño X-Small, con suspensión automática a los 60 segundos sin uso y reanudación automática al consultar. Al terminar el trabajo: [suspendido / encendido].
