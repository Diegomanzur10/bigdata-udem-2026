
-- =====================================================================
-- TALLER 1 · 05_retos.sql · Respuesta a retos opcionales
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- RETO R1: Un segundo caso completo (cinco preguntas más) --> Caso seleccionado B

-- ---------------------------------------------------------------------
-- Pregunta B1: Viajes por día con lluvia y sin lluvia, sin contar filas como días
-- ---------------------------------------------------------------------

WITH VIAJES_DIA AS (
    SELECT FECHA, SUM(VIAJES) AS VIAJES_DIA
    FROM FACT_VIAJES_DIA
    GROUP BY FECHA
)
SELECT
    IFF(D.LLUVIA_MM > 0, 'Con lluvia', 'Sin lluvia') AS TIPO_DIA,
    COUNT(DISTINCT D.FECHA)                          AS DIAS,
    SUM(V.VIAJES_DIA)                                AS VIAJES_TOTALES,
    ROUND(AVG(V.VIAJES_DIA), 0)                      AS AVG_VIAJES_POR_DIA
FROM DIM_FECHA D
JOIN VIAJES_DIA V ON D.FECHA = V.FECHA
GROUP BY IFF(D.LLUVIA_MM > 0, 'Con lluvia', 'Sin lluvia')
ORDER BY TIPO_DIA;
-- Interpretación: En los 48 días con lluvia (LLUVIA_MM > 0) las plataformas registraron en
-- promedio 678 188 viajes por día (columna AVG_VIAJES_POR_DIA), frente a 644 546 en los 43 días
-- sin lluvia: unos 33 600 viajes más por día, cerca de 5,2 %.
-- Se concluye que en el trimestre, los días con lluvia se asociaron con un mayor uso de las
-- plataformas; la demanda de viajes fue mayor cuando llovió que cuando no.
-- Trampa: los días suman 91 y los viajes 60 268 466, igual que DIM_FECHA y el
-- paquete. Por eso la lluvia, que se repite en unas 500 filas por día, no se sumó ni se
-- contaron filas como días (Esto corresponde a la trampa 1).
-- Tomar en cuenta que día con lluvia = LLUVIA_MM > 0; así,
-- No es posible asegurar que la lluvia cause el aumento de viajes, pero si se puede concluir que es un factor
--importante para que se usen con mayor demanda las plataforma de movilidad.

-- ---------------------------------------------------------------------
-- Pregunta B2: Días con un salto de más de 50 % frente al día anterior (por zona)
-- ---------------------------------------------------------------------

WITH ZONAS AS (
    SELECT DISTINCT ZONA FROM FACT_VIAJES_DIA
),
VIAJES_ZONA_DIA AS (
    SELECT Z.ZONA, D.FECHA, D.DIA_SEMANA, D.LLUVIA_MM,
           COALESCE(SUM(F.VIAJES), 0) AS VIAJES_DIA
    FROM ZONAS Z
    CROSS JOIN DIM_FECHA D
    LEFT JOIN FACT_VIAJES_DIA F ON F.ZONA = Z.ZONA AND F.FECHA = D.FECHA
    GROUP BY Z.ZONA, D.FECHA, D.DIA_SEMANA, D.LLUVIA_MM
),
CON_LAG AS (
    SELECT ZONA, FECHA, DIA_SEMANA, LLUVIA_MM, VIAJES_DIA,
           LAG(VIAJES_DIA) OVER (PARTITION BY ZONA ORDER BY FECHA) AS VIAJES_DIA_ANTERIOR
    FROM VIAJES_ZONA_DIA
)
SELECT
    ZONA, FECHA, DIA_SEMANA, LLUVIA_MM, VIAJES_DIA, VIAJES_DIA_ANTERIOR,
    ROUND(100.0 * (VIAJES_DIA - VIAJES_DIA_ANTERIOR) / VIAJES_DIA_ANTERIOR, 2) AS VARIACION_PCT
FROM CON_LAG
WHERE VIAJES_DIA_ANTERIOR > 0
  AND VIAJES_DIA > 1.5 * VIAJES_DIA_ANTERIOR
ORDER BY VARIACION_PCT DESC;

-- Interpretación: Con el umbral de más de 50 % frente al día anterior, por zona y sin mínimo de
-- viajes(este concepto hace referencia a un umbral que serviría para determinar que el analizis
--debería de realizarse sobre una cantidad minima de viajes. Ya que con viajes pequeños
-- en zonas especificas da falsas expectativas de aumento de la demanda. Ejemplo. Una zona que pase de 1 a 10 viaje 
--poseería un aumento de 10 veces. El equipo decide no colocar un minmo para poder analizar todo
--el panorama real de información que ofrece la consulta. El 1 de enero no tiene día anterior por lo que no se considera día de salto)
--Para esa fecha se deja en null usando LAG() para su identificación.
-- Observación: El 14 de febrero (miércoles, sin lluvia) concentra 150 de los 545 saltos
-- (27,5 %), uno por cada una de 150 zonas y con aumentos muy parecidos (mediana de 62,5 %). El equipo intuye que este salto
-- puede ser provocado con la fecha de san valentine que es celebrado el día 14 de febrero en estados unidos (NYC).
-- Sumadas, esas 150 zonas pasaron de 241 521 a 391 942 viajes (+62,3 %). 
-- LAG compara con el día de ayer y no con el mismo día de la semana, por eso el
-- ciclo semanal aparece como saltos: 216 de los 545 (55 % de los 395 sin el 14 de febrero) caen en
-- sábado (152) o domingo (64). Los saltos de más de 100 % en zonas grandes (12 de las 275 filas con
-- 1 000 viajes o más el día anterior) son todos de fin de semana: 10 domingos, cinco de LaGuardia
-- Airport y cinco de Borough Park, y 2 sábados. Parece un ciclo repetido por alta demanda que ofrece los servicios de 
--aeropuerto o sitios turisticos como parques.
-- Trampas y decisiones: Se selecciona un umbral de > 0 para VIAJES_DIA_ANTERIOR entendiendo que puede
-- provocar sesgos en las zonas que posean muy pocos viajes. Con este umbral no se cuentan las zonas
-- que reaparecen tras un día sin viajes, y el umbral del salto es estrictamente mayor a 50 %. 

-- ---------------------------------------------------------------------
-- Pregunta B3: Media móvil de 7 días de viajes por zona
-- ---------------------------------------------------------------------

WITH ZONAS AS (
    SELECT DISTINCT ZONA FROM FACT_VIAJES_DIA
),
VIAJES_ZONA_DIA AS (
    SELECT Z.ZONA, D.FECHA,
           COALESCE(SUM(F.VIAJES), 0) AS VIAJES_DIA
    FROM ZONAS Z
    CROSS JOIN DIM_FECHA D
    LEFT JOIN FACT_VIAJES_DIA F ON F.ZONA = Z.ZONA AND F.FECHA = D.FECHA
    GROUP BY Z.ZONA, D.FECHA
)
SELECT
    ZONA, FECHA, VIAJES_DIA,
    ROUND(AVG(VIAJES_DIA) OVER (
        PARTITION BY ZONA ORDER BY FECHA
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS MEDIA_MOVIL_7D,
    COUNT(*) OVER (
        PARTITION BY ZONA ORDER BY FECHA
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)     AS DIAS_EN_VENTANA
FROM VIAJES_ZONA_DIA
QUALIFY DIAS_EN_VENTANA = 7
ORDER BY ZONA, FECHA;
-- Interpretación: 
-- Sumando las zonas, la media móvil pasa de 584 942 viajes por día (7 de enero) a un máximo
-- de 709 138 (6 de marzo) y cierra en 662 788 (31 de marzo): 13 % más que al inicio y 6,5 % menos
-- que el máximo. La mediana de las zonas también sube 13,4 % entre la primera y la última ventana.
-- La media móvil suaviza el ciclo semanal: los totales diarios van de 507 771 a 884 219 viajes (los
-- sábados promedian 801 518 y los lunes 565 816), mientras que la media móvil se mueve entre
-- 567 989 y 709 138.
-- Un día atípico se arrastra 7 días: el 13 de febrero (507 771 viajes, el día más bajo del periodo)
-- baja la media móvil de la ciudad de 667 316 a 656 080, y al día siguiente sube a 675 914.
-- Zonas: 189 de las 261 zonas promedian 1 000 viajes por día o más y 20, menos de 100. Casi sin
-- servicio están Newark Airport (0,02 viajes por día; 83 de 85 días en 0), Governor's Island/Ellis
-- Island/Liberty Island (0,08), Rikers Island (0,19), Great Kills Park y Jamaica Bay (0,81); en las
-- tres primeras la media móvil queda en 0 en 126 filas, y en ellas no sirve para ver tendencias.
-- Aeropuertos: JFK Airport empieza en su máximo (13 823 el 7 de enero, ventana del 1 al 7 que
-- incluye el festivo del 1 de enero), baja a 9 951 el 7 de febrero y cierra en 12 096; LaGuardia
-- Airport sube de 10 228 a un máximo de 12 977 (26 de marzo) y cierra en 12 208. Los datos no
-- explican esa diferencia de comportamiento.

-- ---------------------------------------------------------------------
-- Pregunta B4: Las tres zonas con más viajes por día de la semana
-- ---------------------------------------------------------------------

WITH DIAS AS (
    SELECT DIA_SEMANA, COUNT(*) AS DIAS_DEL_TIPO
    FROM DIM_FECHA
    GROUP BY DIA_SEMANA
)
SELECT
    D.DIA_SEMANA,
    F.ZONA,
    SUM(F.VIAJES)                             AS TOTAL_VIAJES,
    ROUND(SUM(F.VIAJES) / X.DIAS_DEL_TIPO, 0) AS PROMEDIO_VIAJES_DIA,
    RANK() OVER (PARTITION BY D.DIA_SEMANA ORDER BY SUM(F.VIAJES) DESC) AS RANKING
FROM FACT_VIAJES_DIA F
JOIN DIM_FECHA D ON F.FECHA = D.FECHA
JOIN DIAS X      ON X.DIA_SEMANA = D.DIA_SEMANA
GROUP BY D.DIA_SEMANA, F.ZONA, X.DIAS_DEL_TIPO
QUALIFY RANKING <= 3
ORDER BY
    CASE D.DIA_SEMANA
        WHEN 'Lunes' THEN 1 WHEN 'Martes' THEN 2 WHEN 'Miércoles' THEN 3
        WHEN 'Jueves' THEN 4 WHEN 'Viernes' THEN 5 WHEN 'Sábado' THEN 6
        ELSE 7 END,
    RANKING;
-- Interpretación: La consulta devuelve 21 filas, 3 zonas por cada día de la semana, sin empates en
-- el ranking (con empates saldrían más de 3). Cada día de la semana aparece 13 veces en los 91 días y
-- PROMEDIO_VIAJES_DIA es el total dividido entre 13, así que el ranking es el mismo con el total o
-- con el promedio. Solo 7 zonas distintas ocupan los 21 puestos.
-- LaGuardia Airport es la zona con más viajes de lunes a viernes y JFK Airport la
-- segunda; los domingos se invierten (JFK 179 050 viajes y LaGuardia 166 186). La diferencia entre
-- ambas es pequeña los lunes (3 %), martes (5 %) y viernes (4 %), y mayor los miércoles (15 %) y
-- jueves (20 %).
-- El tercer lugar cambia: Crown Heights North el lunes (7 387 viajes por día, 54 % de los de JFK),
-- Midtown Center de martes a jueves, y East Village el viernes y el domingo.
-- Los sabados East Village lidera con 210 123 viajes (16 163 por día, el
-- mayor promedio de la tabla), 32 % más que Lower East Side (159 360), seguido de Williamsburg
-- (North Side) (148 078).

-- ---------------------------------------------------------------------
-- Pregunta B5: Viajes en festivos frente al promedio del mismo día de la semana
-- ---------------------------------------------------------------------
WITH VIAJES_DIA AS (
    SELECT D.FECHA, D.DIA_SEMANA, SUM(F.VIAJES) AS VIAJES_DIA
    FROM FACT_VIAJES_DIA F
    JOIN DIM_FECHA D ON F.FECHA = D.FECHA
    GROUP BY D.FECHA, D.DIA_SEMANA
),
MARCADO AS (
    SELECT V.FECHA, V.DIA_SEMANA, V.VIAJES_DIA, H.NOMBRE AS FESTIVO
    FROM VIAJES_DIA V
    LEFT JOIN CURSO.LAB4.FESTIVOS_2024 H ON V.FECHA = H.FECHA
),
BASE AS (
    SELECT DIA_SEMANA,
           COUNT(*)                  AS DIAS_BASE,
           ROUND(AVG(VIAJES_DIA), 0) AS PROMEDIO_NO_FESTIVOS
    FROM MARCADO
    WHERE FESTIVO IS NULL
    GROUP BY DIA_SEMANA
)
SELECT
    M.FECHA, M.FESTIVO, M.DIA_SEMANA, M.VIAJES_DIA,
    B.DIAS_BASE, B.PROMEDIO_NO_FESTIVOS,
    M.VIAJES_DIA - B.PROMEDIO_NO_FESTIVOS AS DIFERENCIA,
    ROUND(100.0 * (M.VIAJES_DIA - B.PROMEDIO_NO_FESTIVOS) / B.PROMEDIO_NO_FESTIVOS, 2) AS VARIACION_PCT
FROM MARCADO M
JOIN BASE B ON M.DIA_SEMANA = B.DIA_SEMANA
WHERE M.FESTIVO IS NOT NULL
ORDER BY M.FECHA;
-- Interpretación: El 1 de enero (Año Nuevo) tuvo 638 085 viajes, 70 272 más que la base (+12,4 %); el
-- 15 de enero (Martin Luther King) tuvo 559 061, 8 752 menos (-1,5 %), y el 19 de febrero
-- (Washington) tuvo 552 593, 15 220 menos (-2,7 %).
-- Solo el 1 de enero se sale de lo normal. Se puede deducir que se debe a los viajes que provoca
--año nuevo con el fin de reuniones familiares u otras celebraciones dentro de NYC. Los 10 lunes de la base van de 519 411 a
-- 598 465 viajes (de -8,5 % a +5,4 % frente a su promedio): los otros dos festivos caen dentro de
-- ese rango y no se distinguen de un lunes cualquiera, mientras que el 1 de enero queda 6,6 % por
-- encima del lunes más alto de la base.

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
