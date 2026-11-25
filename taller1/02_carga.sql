-- =====================================================================
-- TALLER 1 · 02_carga.sql · Carga de la estrella desde CURSO.LAB4
-- Equipo: Natasha Orozco, Miguel Angel Vélez, Xiomy Baquero · Anfitriona: Natasha Orozco · Caso: A
-- =====================================================================


USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- ---------------------------------------------------------------------
-- 1. DIM_EMPRESA: una fila por empresa, construida desde el gold (no escrita a mano).
-- ---------------------------------------------------------------------
TRUNCATE TABLE DIM_EMPRESA;
INSERT INTO DIM_EMPRESA (EMPRESA_KEY, EMPRESA)
SELECT ROW_NUMBER() OVER (ORDER BY EMPRESA), EMPRESA
FROM (SELECT DISTINCT EMPRESA FROM CURSO.LAB4.DAILY_ZONE_METRICS);

-- ---------------------------------------------------------------------
-- 2. DIM_ZONA: una fila por NOMBRE de zona 
-- ---------------------------------------------------------------------
TRUNCATE TABLE DIM_ZONA;
INSERT INTO DIM_ZONA (ZONA_KEY, ZONA, BOROUGH, SERVICE_ZONE)
SELECT ROW_NUMBER() OVER (ORDER BY ZONA), ZONA, ANY_VALUE(BOROUGH), ANY_VALUE(SERVICE_ZONE)
FROM CURSO.LAB4.DIM_ZONA
GROUP BY ZONA;

-- ---------------------------------------------------------------------
-- 3. DIM_FECHA: un día por fila, entre el primer y el último día del gold.
--    La lluvia del día se guarda una sola vez (MAX por fecha, no suma de filas).
-- ---------------------------------------------------------------------
TRUNCATE TABLE DIM_FECHA;
INSERT INTO DIM_FECHA (FECHA, ANIO, MES, DIA_SEMANA, ES_FIN_DE_SEMANA, ES_FESTIVO, LLUVIA_MM)
WITH r AS (
  SELECT MIN(FECHA) AS MINF, MAX(FECHA) AS MAXF FROM CURSO.LAB4.DAILY_ZONE_METRICS
),
d AS (
  SELECT DATEADD('day', ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, MINF) AS FECHA
  FROM r, TABLE(GENERATOR(ROWCOUNT => 400))
  QUALIFY FECHA <= MAXF
),
l AS (
  SELECT FECHA, MAX(LLUVIA_MM) AS LLUVIA_MM
  FROM CURSO.LAB4.DAILY_ZONE_METRICS
  GROUP BY FECHA
)
SELECT d.FECHA,
       YEAR(d.FECHA),
       MONTH(d.FECHA),
       DAYNAME(d.FECHA),
       DAYOFWEEKISO(d.FECHA) IN (6, 7),
       f.FECHA IS NOT NULL,
       l.LLUVIA_MM
FROM d
LEFT JOIN l                          ON l.FECHA = d.FECHA
LEFT JOIN CURSO.LAB4.FESTIVOS_2024 f ON f.FECHA = d.FECHA;

-- ---------------------------------------------------------------------
-- 4. FACT_VIAJES_DIA: una fila por fecha, zona y empresa del gold.
--    Las medidas se pasan a sumas: PROPINA_TOTAL = PROPINA_PROMEDIO x VIAJES, y lo mismo con DISTANCIA.
-- ---------------------------------------------------------------------
TRUNCATE TABLE FACT_VIAJES_DIA;
INSERT INTO FACT_VIAJES_DIA (FECHA, ZONA_KEY, EMPRESA_KEY, VIAJES, INGRESO_TOTAL, PROPINA_TOTAL, DISTANCIA_TOTAL)
SELECT g.FECHA,
       z.ZONA_KEY,
       e.EMPRESA_KEY,
       g.VIAJES,
       g.INGRESO_TOTAL,
       g.PROPINA_PROMEDIO * g.VIAJES,
       g.DISTANCIA_PROMEDIO * g.VIAJES
FROM CURSO.LAB4.DAILY_ZONE_METRICS g
JOIN DIM_ZONA    z ON z.ZONA    = g.ZONA
JOIN DIM_EMPRESA e ON e.EMPRESA = g.EMPRESA;

-- ---------------------------------------------------------------------
-- 5. CONTROLES DE CARGA (pegar los resultados)
-- ---------------------------------------------------------------------
-- Filas del gold contra filas del hecho: deben ser iguales (46715). Si el hecho tiene menos, el join dejó filas fuera.
SELECT (SELECT COUNT(*) FROM CURSO.LAB4.DAILY_ZONE_METRICS) AS FILAS_GOLD,
       (SELECT COUNT(*) FROM FACT_VIAJES_DIA)               AS FILAS_HECHO;

-- Total de viajes: 
SELECT SUM(VIAJES) AS VIAJES FROM FACT_VIAJES_DIA;

-- Días: 
SELECT COUNT(*) AS DIAS FROM DIM_FECHA;

-- Zonas y empresas: 
SELECT (SELECT COUNT(*) FROM DIM_ZONA)    AS ZONAS,
       (SELECT COUNT(*) FROM DIM_EMPRESA) AS EMPRESAS;
