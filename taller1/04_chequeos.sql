-- =====================================================================
-- TALLER 1 · 04_chequeos.sql · Los cuatro controles de integridad (esqueleto)
-- =====================================================================
-- Los cuatro controles del enunciado (sección 15): filas, grano único, sin huérfanos y viajes, se implementan chequeos adicionales.
-- totales contra el origen. Debajo está la consulta del enunciado como punto de partida:
-- descoméntala y ajusta los nombres de tus llaves (ZONA_KEY, EMPRESA_KEY) a los de tu estrella.
-- Salida esperada: cuatro filas con HECHO igual a ESPERADO.
-- Si `filas` o `viajes` no coinciden, revisa la trampa 4; si `grano` es menor que `filas`, hay duplicados.
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

SELECT 'filas' AS CONTROL, COUNT(*) AS HECHO, 46715 AS ESPERADO
FROM CURSO.T1.FACT_VIAJES_DIA
UNION ALL
SELECT 'grano', COUNT(DISTINCT FECHA || '|' || ZONA || '|' || EMPRESA), 46715
FROM CURSO.T1.FACT_VIAJES_DIA
UNION ALL
SELECT 'sin zona', COUNT(*), 0
FROM CURSO.T1.FACT_VIAJES_DIA F LEFT JOIN CURSO.T1.DIM_ZONA Z USING (ZONA)
WHERE Z.ZONA IS NULL
UNION ALL
SELECT 'viajes', SUM(VIAJES), 60268466
FROM CURSO.T1.FACT_VIAJES_DIA
UNION ALL
-- SE IMPLEMENTAN LOS SIGUIENTES CHEQUEOS ADICIONALES A LOS CUATRO PROPUESTOS INICIALMENTE
-- Validación de viajes y filas totales contra el origen, consultando la cantidad del origen directamente sin tomar simplmente el numero
-- Se emplea únicamente para validar y confirmar que funciona de la misma manera
SELECT 'filas totales contra origen', COUNT(*),
       (SELECT COUNT(*) FROM CURSO.LAB4.DAILY_ZONE_METRICS)
FROM CURSO.T1.FACT_VIAJES_DIA
UNION ALL
SELECT 'viajes totales contra origen', SUM(VIAJES),
       (SELECT SUM(VIAJES) FROM CURSO.LAB4.DAILY_ZONE_METRICS)
FROM CURSO.T1.FACT_VIAJES_DIA
UNION ALL
-- Adicionalmente, se implementan chequeos para resvisar los sin fecha o sin empresa (huérfanas).
SELECT 'sin fecha', COUNT(*), 0
FROM CURSO.T1.FACT_VIAJES_DIA F LEFT JOIN CURSO.T1.DIM_FECHA D USING (FECHA)
WHERE D.FECHA IS NULL
UNION ALL
SELECT 'sin empresa', COUNT(*), 0
FROM CURSO.T1.FACT_VIAJES_DIA F LEFT JOIN CURSO.T1.DIM_EMPRESA D USING (EMPRESA)
WHERE D.EMPRESA IS NULL
UNION ALL
-- Control de unicidad en la dimensión de zona
SELECT 'dimensión_zona',  COUNT(*), COUNT(DISTINCT ZONA) FROM DIM_ZONA;
