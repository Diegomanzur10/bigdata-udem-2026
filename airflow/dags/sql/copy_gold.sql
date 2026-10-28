-- Carga la capa gold (Parquet escrito por el pipeline en Glue) a Snowflake.
-- Stage externo BIGDATA.GOLD.LAKE_GOLD -> s3://<lake>/gold/ (infra/snowflake).
--
-- Layout en S3: gold/daily_zone_metrics/mes=YYYY-MM/*.parquet. La columna `fecha` va dentro de
-- los archivos; la carpeta mes=... solo sirve para reprocesar un mes sin tocar los demas.
-- Orden y tipos de columnas = contrato de gold (src/pipeline/gold.py, COLUMNAS).
--
-- Idempotencia / reprocesos: antes del COPY se borra el mes en la tabla, y el COPY usa FORCE = TRUE
-- (Snowflake recuerda 64 dias los archivos ya cargados; sin FORCE, repetir la carga de un mes cuyos
-- archivos no cambiaron cargaria 0 filas despues del DELETE). {{ params.mes }} viene del DAG.

CREATE TABLE IF NOT EXISTS BIGDATA.GOLD.DAILY_ZONE_METRICS (
    FECHA               DATE,
    ZONA                VARCHAR,
    VIAJES              NUMBER(38, 0),
    INGRESO_TOTAL       FLOAT,
    PROPINA_PROMEDIO    FLOAT,
    DISTANCIA_PROMEDIO  FLOAT,
    LLUVIA_MM           FLOAT
);

DELETE FROM BIGDATA.GOLD.DAILY_ZONE_METRICS
WHERE FECHA >= TO_DATE('{{ params.mes }}-01')
  AND FECHA < DATEADD(MONTH, 1, TO_DATE('{{ params.mes }}-01'));

COPY INTO BIGDATA.GOLD.DAILY_ZONE_METRICS
FROM '@BIGDATA.GOLD.LAKE_GOLD/daily_zone_metrics/mes={{ params.mes }}/'
FILE_FORMAT = (TYPE = PARQUET)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
PATTERN = '.*[.]parquet'
FORCE = TRUE;
