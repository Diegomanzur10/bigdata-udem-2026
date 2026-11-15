
-- =====================================================================
-- TALLER 1 · 05_retos.sql · Respuesta a retos opcionales
-- =====================================================================

-- RETO R2: DIM_FECHA con festivos y fin de semana, usada en una consulta
SELECT
    D.ES_FIN_SEMANA,
    D.ES_FESTIVO,
    COUNT(*)                        AS DIAS,
    ROUND(AVG(TV.TOTAL_VIAJES), 0)  AS PROMEDIO_VIAJES_DIA
FROM (
    SELECT FECHA, SUM(VIAJES) AS TOTAL_VIAJES
    FROM FACT_VIAJES_DIA
    GROUP BY FECHA
) TV
JOIN DIM_FECHA D ON D.FECHA = TV.FECHA
GROUP BY D.ES_FIN_SEMANA, D.ES_FESTIVO
ORDER BY D.ES_FIN_SEMANA, D.ES_FESTIVO;

-- RETO R3: Lluvia fuerte (> 10 mm) frente a la línea base del mismo día
WITH DemandaDiaria AS (
    SELECT F.ZONA, D.FECHA, D.DIA_SEMANA, D.LLUVIA_MM, SUM(F.VIAJES) AS TOTAL_VIAJES
    FROM FACT_VIAJES_DIA F
    JOIN DIM_FECHA D ON F.FECHA = D.FECHA
    GROUP BY F.ZONA, D.FECHA, D.DIA_SEMANA, D.LLUVIA_MM
),
Comparativo AS (
    SELECT
        ZONA, FECHA, LLUVIA_MM, TOTAL_VIAJES,
        ROUND(AVG(CASE WHEN LLUVIA_MM <= 10 THEN TOTAL_VIAJES END)
              OVER (PARTITION BY ZONA, DIA_SEMANA), 2) AS LINEA_BASE_DIA_SEMANA
    FROM DemandaDiaria
)
SELECT
    ZONA, FECHA, LLUVIA_MM, TOTAL_VIAJES, LINEA_BASE_DIA_SEMANA,
    ROUND(TOTAL_VIAJES - LINEA_BASE_DIA_SEMANA, 2) AS DIFERENCIA,
    ROUND(100.0 * (TOTAL_VIAJES - LINEA_BASE_DIA_SEMANA)
          / NULLIF(LINEA_BASE_DIA_SEMANA, 0), 2)   AS VARIACION_PCT
FROM Comparativo
WHERE LLUVIA_MM > 10
ORDER BY TOTAL_VIAJES DESC;


-- RETO R5: Rachas de alta demanda (días consecutivos sobre un umbral; el problema de «huecos e islas»)
WITH DiasSuperavit AS (
    SELECT ZONA, FECHA, SUM(VIAJES) AS VIAJES_DIA
    FROM FACT_VIAJES_DIA
    GROUP BY ZONA, FECHA
    HAVING SUM(VIAJES) > 5000
),
Islas AS (
    SELECT
        ZONA,
        FECHA,
        VIAJES_DIA,
        DATEADD('day',
                -ROW_NUMBER() OVER (PARTITION BY ZONA ORDER BY FECHA),
                FECHA) AS GRUPO_ISLA
    FROM DiasSuperavit
)
SELECT
    ZONA,
    MIN(FECHA)        AS INICIO_RACHA,
    MAX(FECHA)        AS FIN_RACHA,
    COUNT(*)          AS DIAS_CONSECUTIVOS,
    SUM(VIAJES_DIA)   AS VIAJES_TOTALES_RACHA
FROM Islas
GROUP BY ZONA, GRUPO_ISLA
ORDER BY DIAS_CONSECUTIVOS DESC, ZONA, INICIO_RACHA;
