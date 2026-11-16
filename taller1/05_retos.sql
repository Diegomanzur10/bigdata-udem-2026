
-- =====================================================================
-- TALLER 1 · 05_retos.sql · Respuesta a retos opcionales
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- RETO R2: DIM_FECHA con festivos y fin de semana, usada en una consulta
--Pregunta a resolver ¿Qué empresa usará más los habitantes de NYC durante los fines de semanas y días festivos?
SELECT    
    FVD.EMPRESA,    
    SUM(FVD.VIAJES) AS CantidadViajes,
    SUM(FVD.INGRESO_TOTAL) AS IngresosTotales
FROM DIM_FECHA DF 
RIGHT JOIN FACT_VIAJES_DIA FVD ON FVD.FECHA = DF.FECHA
where DF.es_fin_semana = TRUE OR DF.es_festivo = true
group by FVD.EMPRESA
ORDER BY CantidadViajes DESC, IngresosTotales DESC;
--Respuesta: Los habitantes de NYC en el periodo del primer trimestre del 2024, los fines de semanas y festivos prefieren usar más la plataforma UBER con un total de 15.206.603
--viajes registrados otorgando un ingreso de 453.115.708,34 USD. Lyft presenta 5.508.694 viajes con ingresos totales de 163.319.086,02 USD.
--Lo que indica que los fines de semanas UBER realiza cerca de 2.8 veces más viajes que Lyft y gana en proporcion aproximadamente 2.8 veces más dinero que Lyft. 
--Esta respuesta es importante para UBER para prepararse operativamente frente a la gran demanda de transporte que se tiene los fines de semana y días festivos.

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

-- RETO R6: Tabla externa de Athena sobre el paquete (la del Lab 4, E7) y reconciliación de conteos con Snowflake: 
-- filas por mes y viajes totales, con captura de Data scanned
-- Query para conocer cantidad de filas por mes y viajes totales por mes
SELECT D.MES, COUNT(*) AS FILAS, SUM(F.VIAJES) AS VIAJES
FROM CURSO.T1.FACT_VIAJES_DIA F
JOIN CURSO.T1.DIM_FECHA D ON F.FECHA = D.FECHA
GROUP BY D.MES
ORDER BY D.MES;
