-- =====================================================================
-- TALLER 1 · 02_carga.sql · Carga reproducible desde el Lab 4 (esqueleto)
-- =====================================================================
-- CÓMO USAR ESTE ARCHIVO
--   Reemplaza cada línea «TODO» por tu sentencia (INSERT INTO ... SELECT o CREATE TABLE ... AS
--   SELECT). El archivo se puede correr más de una vez y deja siempre el mismo resultado: carga
--   las dimensiones primero y el hecho después. Los datos de partida están en CURSO.LAB4:
--   DAILY_ZONE_METRICS (46715 filas), DIM_ZONA (265 filas) y FESTIVOS_2024 (11 filas).
--
-- ANTES DE CARGAR EL HECHO
--   Si unes el gold con DIM_ZONA por el nombre de la zona, cuenta las filas antes y después de
--   unir: 46715 antes (trampa 4 del enunciado).
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

--Codigo preventivo de borrado de datos en caso de que ya esten completa la informacion de las tablas a cargar
TRUNCATE TABLE FACT_VIAJES_DIA;
TRUNCATE TABLE DIM_EMPRESA;
TRUNCATE TABLE DIM_ZONA;
TRUNCATE TABLE DIM_FECHA;

-- TODO · Carga de DIM_EMPRESA.
INSERT INTO DIM_EMPRESA
SELECT DISTINCT EMPRESA 
FROM CURSO.LAB4.DAILY_ZONE_METRICS;

-- TODO · Carga de DIM_ZONA (una fila por nombre de zona).
INSERT INTO DIM_ZONA
SELECT DISTINCT 
    ZONA,
    BOROUGH,
    SERVICE_ZONE
FROM CURSO.LAB4.DIM_ZONA 
WHERE ZONA 
NOT LIKE 'N/A';

-- TODO · Carga de DIM_FECHA (los días entre el primero y el último del gold; la lluvia del día una sola vez).
INSERT INTO DIM_FECHA
WITH r AS (SELECT MIN(FECHA) AS MINF, MAX(FECHA) AS MAXF FROM CURSO.LAB4.DAILY_ZONE_METRICS),
dias AS (
    SELECT DATEADD('day', ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, MINF) AS FECHA
    FROM r, TABLE(GENERATOR(ROWCOUNT => 400))
    QUALIFY FECHA <= MAXF
)
SELECT 
    d.FECHA,
    EXTRACT(YEAR FROM d.FECHA) AS ANIO,
    EXTRACT(MONTH FROM d.FECHA) AS MES,
    DECODE(DAYOFWEEK(d.FECHA), 0, 'Domingo', 1, 'Lunes', 2, 'Martes', 3, 'Miércoles', 4, 'Jueves', 5, 'Viernes', 6, 'Sábado') AS DIA_SEMANA,
    CASE WHEN DAYOFWEEK(d.FECHA) IN (0, 6) THEN TRUE ELSE FALSE END AS ES_FIN_SEMANA,
    CASE WHEN f.FECHA IS NOT NULL THEN TRUE ELSE FALSE END AS ES_FESTIVO,
    COALESCE(m.LLUVIA_MM, 0) AS LLUVIA_MM
FROM dias d
LEFT JOIN CURSO.LAB4.FESTIVOS_2024 f ON d.FECHA = f.FECHA
LEFT JOIN (
    SELECT FECHA, MAX(LLUVIA_MM) AS LLUVIA_MM 
    FROM CURSO.LAB4.DAILY_ZONE_METRICS 
    GROUP BY FECHA
) m ON d.FECHA = m.FECHA;
  
-- TODO · Carga de FACT_VIAJES_DIA.
INSERT INTO FACT_VIAJES_DIA
SELECT 
    FECHA,
    ZONA,
    EMPRESA,
    VIAJES,
    INGRESO_TOTAL,
    PROPINA_PROMEDIO,
    DISTANCIA_PROMEDIO
FROM CURSO.LAB4.DAILY_ZONE_METRICS;

-- Conteo de control contra el paquete: 46715 filas y 60268466 viajes.
SELECT COUNT(*) AS FILAS, SUM(VIAJES) AS VIAJES FROM CURSO.T1.FACT_VIAJES_DIA;

