-- ================================================================================================
-- TALLER 1 · RETOS OPCIONALES
-- ================================================================================================
-- Equipo: Natasha Orozco, Miguel Angel Vélez, Xiomy Baquero · Anfitriona: Natasha Orozco · Caso: A
-- ================================================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- ================================================================================================
-- R2: DIM_FECHA con festivos y fin de semana, usada en una consulta
-- ================================================================================================

WITH viajes_diarios AS (
  SELECT FECHA, SUM(VIAJES) AS VIAJES
  FROM FACT_VIAJES_DIA
  GROUP BY FECHA
)
SELECT CASE
         WHEN d.ES_FESTIVO THEN 'Festivo'
         WHEN d.ES_FIN_DE_SEMANA THEN 'Fin de semana'
         ELSE 'Día laboral'
       END AS TIPO_DIA,
       COUNT(*) AS NUMERO_DIAS,
       SUM(v.VIAJES) AS TOTAL_VIAJES,
       ROUND(AVG(v.VIAJES), 2) AS PROMEDIO_DIARIO
FROM viajes_diarios v
JOIN DIM_FECHA d USING (FECHA)
GROUP BY TIPO_DIA
ORDER BY PROMEDIO_DIARIO DESC;

-- ================================================================================================
-- R3: Lluvia fuerte (más de 10 mm) frente a la línea base del mismo día de la semana
-- (AVG() OVER (PARTITION BY ZONA, DIA_SEMANA))
-- ================================================================================================


