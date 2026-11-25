-- =====================================================================
-- TALLER 1 · 04_chequeos.sql · Suite de chequeos de la estrella
-- Versión 2 (borrador SIN EJECUTAR en Snowflake: revisar la salida antes de dar nada por bueno).
-- Cada control compara HECHO con ESPERADO. RESULTADO = OK si coinciden (dentro de TOL).
--   · OK        → cumple el requisito del README.
--   · REVISAR   → no cumple; la columna PISTA dice qué revisar.
-- Los controles 1 a 4 son los de la sección 15 del README (núcleo, punto 4).
-- Los demás verifican el resto de requisitos: sección 3 (datos), 6 (estrella),
-- sección 4 (cuatro trampas) y verificar_t1.sql.
-- Ejecutar todo el archivo (Run All) en la cuenta del anfitrión.
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

WITH
-- ---------------------------------------------------------------------
-- A. CONTROLES DEL NÚCLEO (sección 15 del README)
-- ---------------------------------------------------------------------

-- 1 · filas: el hecho tiene las filas del gold de origen (y del paquete).
c1 AS (
  SELECT 'filas (vs origen)' AS CONTROL, 'Núcleo 4 / sec. 15' AS REF,
         (SELECT COUNT(*) FROM FACT_VIAJES_DIA)                  AS HECHO,
         (SELECT COUNT(*) FROM CURSO.LAB4.DAILY_ZONE_METRICS)    AS ESPERADO,
         0 AS TOL,
         'Si no coincide: join que deja filas fuera (revisar nombres de zona, trampa 4).' AS PISTA
),
c1b AS (
  SELECT 'filas (vs paquete)', 'sec. 3 (volumen)',
         (SELECT COUNT(*) FROM FACT_VIAJES_DIA), 46715, 0,
         'El paquete trae 46 715 filas. Si el origen cambió, este control falla.'
),
-- 2 · grano: una fila por fecha × zona × empresa (sin duplicados).
c2 AS (
  SELECT 'grano (filas distintas)', 'sec. 6 (grano) y sec. 15',
         (SELECT COUNT(*) FROM (SELECT DISTINCT FECHA, ZONA_KEY, EMPRESA_KEY FROM FACT_VIAJES_DIA)),
         (SELECT COUNT(*) FROM FACT_VIAJES_DIA),
         0,
         'Si HECHO < ESPERADO hay duplicados de fecha × zona × empresa: revisar la carga (¿se corrió dos veces sin TRUNCATE?).'
),
-- 3 · sin zona huérfana: todo ZONA_KEY del hecho existe en DIM_ZONA.
c3 AS (
  SELECT 'sin zona huérfana', 'sec. 15',
         (SELECT COUNT(*) FROM FACT_VIAJES_DIA f
            WHERE NOT EXISTS (SELECT 1 FROM DIM_ZONA z WHERE z.ZONA_KEY = f.ZONA_KEY)),
         0, 0,
         'Filas del hecho con una zona que no está en DIM_ZONA.'
),
-- 4 · viajes: el total del hecho es el total del origen y del paquete.
c4 AS (
  SELECT 'viajes (vs origen)', 'Núcleo 4 / sec. 15',
         (SELECT SUM(VIAJES) FROM FACT_VIAJES_DIA),
         (SELECT SUM(VIAJES) FROM CURSO.LAB4.DAILY_ZONE_METRICS),
         0,
         'Si no coincide, revisa la trampa 4 (una zona repetida infla los viajes).'
),
c4b AS (
  SELECT 'viajes (vs paquete)', 'sec. 3 (volumen)',
         (SELECT SUM(VIAJES) FROM FACT_VIAJES_DIA), 60268466, 0,
         '60 268 466 viajes según el paquete.'
),

-- ---------------------------------------------------------------------
-- B. HUÉRFANOS ADICIONALES (sec. 6: claves)
-- ---------------------------------------------------------------------
c5 AS (
  SELECT 'sin empresa huérfana', 'sec. 6 (claves)',
         (SELECT COUNT(*) FROM FACT_VIAJES_DIA f
            WHERE NOT EXISTS (SELECT 1 FROM DIM_EMPRESA e WHERE e.EMPRESA_KEY = f.EMPRESA_KEY)),
         0, 0, 'Filas del hecho con una empresa que no está en DIM_EMPRESA.'
),
c6 AS (
  SELECT 'sin fecha huérfana', 'sec. 6 (claves)',
         (SELECT COUNT(*) FROM FACT_VIAJES_DIA f
            WHERE NOT EXISTS (SELECT 1 FROM DIM_FECHA d WHERE d.FECHA = f.FECHA)),
         0, 0, 'Filas del hecho con una fecha que no está en DIM_FECHA.'
),
-- Trampa 4 directa: nombres de zona del gold que no existen en DIM_ZONA.
c7 AS (
  SELECT 'zona del gold sin pareja en DIM_ZONA', 'sec. 4 (trampa 4)',
         (SELECT COUNT(*) FROM CURSO.LAB4.DAILY_ZONE_METRICS g
            WHERE NOT EXISTS (SELECT 1 FROM DIM_ZONA z WHERE z.ZONA = g.ZONA)),
         0, 0, 'Nombres del gold que no encuentran zona en DIM_ZONA: la carga los dejó fuera.'
),

-- ---------------------------------------------------------------------
-- C. DIMENSIONES (sec. 6 y sec. 4, trampa 4)
-- ---------------------------------------------------------------------
-- Dos empresas: Uber y Lyft, sin repetir.
c8 AS (
  SELECT 'empresas en DIM_EMPRESA', 'sec. 3 (Uber y Lyft)',
         (SELECT COUNT(*) FROM DIM_EMPRESA WHERE EMPRESA IN ('Uber', 'Lyft')),
         2, 0, 'Deben existir exactamente Uber y Lyft.'
),
c8b AS (
  SELECT 'empresas distintas (sin repetir)', 'sec. 6 (grano)',
         (SELECT COUNT(DISTINCT EMPRESA) FROM DIM_EMPRESA),
         (SELECT COUNT(*) FROM DIM_EMPRESA), 0,
         'Una fila por empresa: si HECHO < ESPERADO hay empresas repetidas.'
),
-- DIM_ZONA: una fila por nombre de zona. Esperado 262 (sec. 3).
c9 AS (
  SELECT 'zonas en DIM_ZONA (una fila por nombre)', 'sec. 3 y sec. 4 (trampa 4)',
         (SELECT COUNT(*) FROM DIM_ZONA),
         262, 0,
         'Esperado 262 nombres distintos. Si hay 265, la dimensión conserva las filas repetidas de LocationID.'
),
c9b AS (
  SELECT 'nombres de zona repetidos en DIM_ZONA', 'sec. 4 (trampa 4)',
         (SELECT COUNT(*) FROM (SELECT ZONA FROM DIM_ZONA GROUP BY ZONA HAVING COUNT(*) > 1)),
         0, 0, 'Debe ser 0: un nombre de zona por fila.'
),
-- Trampa 4 sobre el origen: el gold también debe tener 262 zonas distintas.
c9c AS (
  SELECT 'zonas distintas en el gold', 'sec. 4 (trampa 4)',
         (SELECT COUNT(DISTINCT ZONA) FROM CURSO.LAB4.DAILY_ZONE_METRICS),
         (SELECT COUNT(*) FROM DIM_ZONA), 0,
         'Las zonas del gold deben coincidir con las de DIM_ZONA. Si difieren, la dimensión no cubre el origen.'
),

-- ---------------------------------------------------------------------
-- D. FECHAS Y FESTIVOS (sec. 3, sec. 6)
-- ---------------------------------------------------------------------
c10 AS (
  SELECT 'días en DIM_FECHA', 'sec. 3 (91 días)',
         (SELECT COUNT(*) FROM DIM_FECHA), 91, 0,
         'Enero, febrero y marzo de 2024: 31 + 29 + 31 = 91 días.'
),
c10b AS (
  SELECT 'días distintos en DIM_FECHA (sin repetir)', 'sec. 6 (grano)',
         (SELECT COUNT(DISTINCT FECHA) FROM DIM_FECHA),
         (SELECT COUNT(*) FROM DIM_FECHA), 0,
         'Un día por fila. Si HECHO < ESPERADO, hay días repetidos: todas las consultas de 03 inflan los viajes.'
),
c10c AS (
  SELECT 'rango de DIM_FECHA = rango del gold', 'sec. 3',
         (SELECT DATEDIFF('day', MIN(FECHA), MAX(FECHA)) FROM DIM_FECHA),
         (SELECT DATEDIFF('day', MIN(FECHA), MAX(FECHA)) FROM CURSO.LAB4.DAILY_ZONE_METRICS), 0,
         'Mismo primer y último día en ambas tablas.'
),
c11 AS (
  SELECT 'festivos de enero a marzo en DIM_FECHA', 'sec. 3 y caso B5 (n = 3)',
         (SELECT COUNT(*) FROM DIM_FECHA WHERE ES_FESTIVO),
         3, 0,
         'Deben ser 1 y 15 de enero y 19 de febrero (tres lunes). Si hay más, DIM_FECHA duplica o cruza festivos.'
),
c11b AS (
  SELECT 'fines de semana en DIM_FECHA', 'sec. 6 (DIM_FECHA)',
         (SELECT COUNT(*) FROM DIM_FECHA WHERE ES_FIN_DE_SEMANA),
         (SELECT COUNT(*) FROM DIM_FECHA WHERE DAYOFWEEKISO(FECHA) IN (6, 7)), 0,
         'Coherencia interna de ES_FIN_DE_SEMANA.'
),

-- ---------------------------------------------------------------------
-- E. LLUVIA (trampa 1): una vez por día, fuera del hecho
-- ---------------------------------------------------------------------
-- El gold debe tener UNA lluvia por día (si varía dentro del día, MAX no sirve).
c12 AS (
  SELECT 'días con lluvia que varía dentro del día (gold)', 'sec. 4 (trampa 1)',
         (SELECT COUNT(*) FROM (
            SELECT FECHA FROM CURSO.LAB4.DAILY_ZONE_METRICS
            GROUP BY FECHA HAVING MIN(LLUVIA_MM) <> MAX(LLUVIA_MM))),
         0, 0, 'Debe ser 0: la lluvia es la misma en todas las filas de un día.'
),
-- DIM_FECHA tiene la lluvia de cada día tal como la da el gold.
c13 AS (
  SELECT 'lluvia de DIM_FECHA vs gold (días distintos)', 'sec. 4 (trampa 1)',
         (SELECT COUNT(*) FROM DIM_FECHA d
            JOIN (SELECT FECHA, MAX(LLUVIA_MM) AS LLUVIA_MM
                  FROM CURSO.LAB4.DAILY_ZONE_METRICS GROUP BY FECHA) g
              ON g.FECHA = d.FECHA
            WHERE IFNULL(d.LLUVIA_MM, -1) <> IFNULL(g.LLUVIA_MM, -1)),
         0, 0, 'Días en que la lluvia de DIM_FECHA no coincide con el gold.'
),
-- La lluvia NO está en el hecho.
c14 AS (
  SELECT 'columnas de lluvia en el hecho', 'sec. 6 (la lluvia no va en el hecho)',
         (SELECT COUNT(*) FROM CURSO.INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = 'T1' AND TABLE_NAME = 'FACT_VIAJES_DIA'
              AND COLUMN_NAME LIKE '%LLUVIA%'),
         0, 0, 'Debe ser 0: la lluvia vive en DIM_FECHA, no en el hecho.'
),

-- ---------------------------------------------------------------------
-- F. MEDIDAS (trampa 2 y trampa 3): sumas aditivas y tolerancia de redondeo
-- ---------------------------------------------------------------------
-- Tolerancia de 1 dólar: se suman 46 715 importes redondeados a centavos.
c15 AS (
  SELECT 'ingreso total (vs origen)', 'sec. 3 y trampa 3',
         (SELECT SUM(INGRESO_TOTAL) FROM FACT_VIAJES_DIA),
         (SELECT SUM(INGRESO_TOTAL) FROM CURSO.LAB4.DAILY_ZONE_METRICS),
         1, 'Tolerancia de 1 dólar por el redondeo de FLOAT.'
),
c16 AS (
  SELECT 'propina total = PROPINA_PROMEDIO x VIAJES (origen)', 'sec. 6 (sumas aditivas)',
         (SELECT SUM(PROPINA_TOTAL) FROM FACT_VIAJES_DIA),
         (SELECT SUM(PROPINA_PROMEDIO * VIAJES) FROM CURSO.LAB4.DAILY_ZONE_METRICS),
         1, 'Si no coincide, la carga no multiplicó la propina por los viajes.'
),
c17 AS (
  SELECT 'distancia total = DISTANCIA_PROMEDIO x VIAJES (origen)', 'sec. 6 (sumas aditivas)',
         (SELECT SUM(DISTANCIA_TOTAL) FROM FACT_VIAJES_DIA),
         (SELECT SUM(DISTANCIA_PROMEDIO * VIAJES) FROM CURSO.LAB4.DAILY_ZONE_METRICS),
         1, 'Igual que la propina, con la distancia.'
),
-- Trampa 3: no comparar FLOAT con '='. La prueba de 0.1 + 0.2 debe dar OK con la tolerancia.
c18 AS (
  SELECT 'prueba de redondeo FLOAT (trampa 3)', 'sec. 4 (trampa 3)',
         (SELECT IFF(ABS((0.1 + 0.2) - 0.3) < 0.01, 1, 0)), 1, 0,
         'Debe ser 1: la comparación con tolerancia funciona aunque 0.1 + 0.2 no sea exactamente 0.3.'
),
-- Valores de referencia que el equipo escribió en 03_preguntas.sql (A2): ponderada por viajes.
c19 AS (
  SELECT 'propina ponderada Lyft (A2)', 'caso A2 (03_preguntas.sql)',
         (SELECT ROUND(SUM(f.PROPINA_TOTAL) / SUM(f.VIAJES), 2)
            FROM FACT_VIAJES_DIA f JOIN DIM_EMPRESA e USING (EMPRESA_KEY) WHERE e.EMPRESA = 'Lyft'),
         1.18, 0.005, 'Valor escrito en 03 (interpretación del equipo). Si no coincide, corregir la interpretación.'
),
c19b AS (
  SELECT 'propina ponderada Uber (A2)', 'caso A2 (03_preguntas.sql)',
         (SELECT ROUND(SUM(f.PROPINA_TOTAL) / SUM(f.VIAJES), 2)
            FROM FACT_VIAJES_DIA f JOIN DIM_EMPRESA e USING (EMPRESA_KEY) WHERE e.EMPRESA = 'Uber'),
         1.06, 0.005, 'Valor escrito en 03 (interpretación del equipo).'
),

-- ---------------------------------------------------------------------
-- G. VERIFICACIÓN DE LA ESTRELLA (verificar_t1.sql)
-- ---------------------------------------------------------------------
c20 AS (
  SELECT 'hecho FACT_VIAJES_DIA existe', 'verificar_t1',
         (SELECT COUNT(*) FROM CURSO.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = 'T1' AND TABLE_NAME = 'FACT_VIAJES_DIA'),
         1, 0, 'Debe existir CURSO.T1.FACT_VIAJES_DIA.'
),
c21 AS (
  SELECT 'dimensiones en CURSO.T1 (al menos 3)', 'verificar_t1',
         (SELECT COUNT(*) FROM CURSO.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = 'T1' AND TABLE_NAME IN ('DIM_FECHA', 'DIM_ZONA', 'DIM_EMPRESA')),
         3, 0, 'Deben existir DIM_FECHA, DIM_ZONA y DIM_EMPRESA.'
)

-- ---------------------------------------------------------------------
-- RESULTADO FINAL: una fila por control.
-- ---------------------------------------------------------------------
SELECT CONTROL, REF, HECHO, ESPERADO,
       IFF(ABS(HECHO - ESPERADO) <= TOL, 'OK', 'REVISAR') AS RESULTADO,
       PISTA
FROM (
  SELECT * FROM c1  UNION ALL SELECT * FROM c1b UNION ALL
  SELECT * FROM c2  UNION ALL SELECT * FROM c3  UNION ALL
  SELECT * FROM c4  UNION ALL SELECT * FROM c4b UNION ALL
  SELECT * FROM c5  UNION ALL SELECT * FROM c6  UNION ALL SELECT * FROM c7  UNION ALL
  SELECT * FROM c8  UNION ALL SELECT * FROM c8b UNION ALL
  SELECT * FROM c9  UNION ALL SELECT * FROM c9b UNION ALL SELECT * FROM c9c UNION ALL
  SELECT * FROM c10 UNION ALL SELECT * FROM c10b UNION ALL SELECT * FROM c10c UNION ALL
  SELECT * FROM c11 UNION ALL SELECT * FROM c11b UNION ALL
  SELECT * FROM c12 UNION ALL SELECT * FROM c13 UNION ALL SELECT * FROM c14 UNION ALL
  SELECT * FROM c15 UNION ALL SELECT * FROM c16 UNION ALL SELECT * FROM c17 UNION ALL
  SELECT * FROM c18 UNION ALL SELECT * FROM c19 UNION ALL SELECT * FROM c19b UNION ALL
  SELECT * FROM c20 UNION ALL SELECT * FROM c21
)
ORDER BY 
  CASE WHEN RESULTADO = 'REVISAR' THEN 0 ELSE 1 END, CONTROL;
