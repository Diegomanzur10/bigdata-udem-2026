-- =====================================================================
-- TALLER 1 · 03_preguntas.sql · Caso A · Competencia entre plataformas
-- Equipo: Natasha Orozco, Miguel Angel Vélez, Xiomy Baquero · Anfitriona: Natasha Orozco
-- =====================================================================
-- Pregunta guía: ¿hay concentración en el mercado de viajes por zona y cómo evoluciona?
-- Las consultas leen la estrella (CURSO.T1). Cada pregunta lleva su consulta y, debajo, su interpretación.
-- Supuestos del caso A (ver también memo.md, sección "Supuestos y definiciones"):
--   · Umbral de volumen: solo se usan zona-mes con al menos 100 viajes en total. Quedan fuera 14 zona-mes
--     (1,8 % de 782), que no permiten una cuota estable (por ejemplo, Jamaica Bay, con 26 y 31 viajes).
--   · A5 solo compara zona-mes con las dos empresas presentes, y solo meses consecutivos.
--   · A5 define el cruce del 70 % como un paso de 70 % o menos a más de 70 %, o al revés (en las dos direcciones).
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- ---------------------------------------------------------------------
-- A1 · Ingresos y viajes por empresa y mes
-- Técnica: GROUP BY
-- ---------------------------------------------------------------------
SELECT e.EMPRESA,
       d.ANIO,
       d.MES,
       SUM(f.VIAJES)                  AS VIAJES,
       ROUND(SUM(f.INGRESO_TOTAL), 2) AS INGRESO_TOTAL
FROM FACT_VIAJES_DIA f
JOIN DIM_EMPRESA e USING (EMPRESA_KEY)
JOIN DIM_FECHA   d USING (FECHA)
GROUP BY e.EMPRESA, d.ANIO, d.MES
ORDER BY e.EMPRESA, d.ANIO, d.MES;

-- Interpretación: Uber tiene el 74 % de los viajes (44,4 M de 60,3 M) y el 74 % del ingreso
-- (1 383 M de 1 858 M dólares). Lyft tiene el 26 % restante. Entre enero y marzo, ambas empresas
-- bajan en febrero y suben en marzo. Lyft cambia más (−5 % y luego +14 %) que Uber (−0,2 % y luego +8,5 %).
-- Lo que no dice: no separa el efecto de la lluvia ni de los festivos, y solo cubre tres meses.

-- ---------------------------------------------------------------------
-- A2 · Propina promedio por empresa, ponderada por viajes
-- Técnica: SUM / SUM (no promedio de promedios)
-- ---------------------------------------------------------------------
SELECT e.EMPRESA,
       SUM(f.VIAJES)                                    AS VIAJES,
       ROUND(SUM(f.PROPINA_TOTAL) / SUM(f.VIAJES), 2)   AS PROPINA_PONDERADA
FROM FACT_VIAJES_DIA f
JOIN DIM_EMPRESA e USING (EMPRESA_KEY)
GROUP BY e.EMPRESA
ORDER BY e.EMPRESA;

-- Interpretación: Lyft deja una propina promedio de 1,18 dólares por viaje, frente a 1,06 de Uber.
-- La diferencia es de 0,12 dólares por viaje (cerca de 11 % más en Lyft). Como la propina se pondera
-- por viajes, el resultado refleja el promedio real de cada empresa y no la media de las dos medias.
-- Lo que no dice: no indica si la propina es un porcentaje de la tarifa, ni si la diferencia viene de
-- zonas, horas o tipo de viaje. Los promedios del gold vienen redondeados a centavos, así que el resultado es aproximado.


-- ---------------------------------------------------------------------
-- A3 · Las tres zonas con más viajes de cada empresa
-- Técnica: RANK con QUALIFY
-- ---------------------------------------------------------------------
WITH por_zona AS (
  SELECT e.EMPRESA, z.ZONA, SUM(f.VIAJES) AS VIAJES
  FROM FACT_VIAJES_DIA f
  JOIN DIM_EMPRESA e USING (EMPRESA_KEY)
  JOIN DIM_ZONA    z USING (ZONA_KEY)
  GROUP BY e.EMPRESA, z.ZONA
)
SELECT EMPRESA,
       ZONA,
       VIAJES,
       RANK() OVER (PARTITION BY EMPRESA ORDER BY VIAJES DESC) AS PUESTO
FROM por_zona
QUALIFY PUESTO <= 3
ORDER BY EMPRESA, PUESTO;

-- Interpretación: Las tres zonas con más viajes son las mismas para las dos empresas: los aeropuertos
-- JFK y LaGuardia, y East Village. Lyft encabeza con LaGuardia (295 689 viajes) y Uber con JFK (810 070).
-- Las tres zonas principales suman cerca del 5 % de los viajes de cada empresa, así que el volumen
-- está muy repartido entre las zonas y no se concentra en unas pocas.
-- Lo que no dice: no mide la concentración en todas las zonas (eso requeriría un índice de concentración,
-- que no está en el caso), ni explica por qué los aeropuertos dominan.

-- ---------------------------------------------------------------------
-- A4 · Cuota de mercado de cada empresa en cada zona y mes
-- Técnica: SUM() OVER (PARTITION BY ZONA, ANIO, MES)
-- ---------------------------------------------------------------------
WITH por_mes AS (
  SELECT z.ZONA, d.ANIO, d.MES, e.EMPRESA, SUM(f.VIAJES) AS VIAJES
  FROM FACT_VIAJES_DIA f
  JOIN DIM_EMPRESA e USING (EMPRESA_KEY)
  JOIN DIM_ZONA    z USING (ZONA_KEY)
  JOIN DIM_FECHA   d USING (FECHA)
  GROUP BY z.ZONA, d.ANIO, d.MES, e.EMPRESA
)
SELECT ZONA,
       ANIO,
       MES,
       EMPRESA,
       VIAJES,
       ROUND(100.0 * VIAJES / SUM(VIAJES) OVER (PARTITION BY ZONA, ANIO, MES), 2) AS CUOTA_PCT
FROM por_mes
ORDER BY ZONA, ANIO, MES, EMPRESA;


-- Interpretación: En las zonas de esta muestra (Allerton/Pelham Gardens, Alphabet City, Arden Heights),
-- Uber tiene entre 68 % y 76 % de los viajes de cada zona cada mes, y Lyft entre 24 % y 32 %.
-- La cuota casi no cambia de un mes a otro en estas zonas (varía menos de 3 puntos).
-- Nota: la tabla tiene 1 560 filas. Hay 4 zona-mes sin viajes y 4 zona-mes con una sola empresa
-- (Governor's Island en enero, Newark Airport en enero y febrero, Rikers Island en marzo).
-- Las de una sola empresa aparecen con 100 % y se excluyen en A5.
-- Lo que no dice: la muestra no cubre todas las zonas, y la cuota no mide ganancias ni competencia.
-- Nota: A4 muestra todas las zona-mes con viajes, incluidas las de menos de 100 viajes, porque la pregunta
-- pide la cuota de cada zona. El umbral de 100 viajes se aplica solo en A5, donde una variación pequeña
-- en zonas con pocos viajes produce cruces falsos del 70 %.

-- ---------------------------------------------------------------------
-- A5 · Variación mensual de la cuota y zonas donde una empresa pasa de 70 %
-- Técnica: LAG
-- Definiciones usadas:
--   · Solo se comparan meses consecutivos en los que operan las dos empresas en la zona.
--   · Hay cruce cuando la cuota pasa de 70 % o menos a más de 70 %.
-- ---------------------------------------------------------------------
WITH por_mes AS (
  SELECT z.ZONA, d.ANIO, d.MES, e.EMPRESA, SUM(f.VIAJES) AS VIAJES
  FROM FACT_VIAJES_DIA f
  JOIN DIM_EMPRESA e USING (EMPRESA_KEY)
  JOIN DIM_ZONA    z USING (ZONA_KEY)
  JOIN DIM_FECHA   d USING (FECHA)
  GROUP BY z.ZONA, d.ANIO, d.MES, e.EMPRESA
),
con_dos AS (
  -- Solo zona-mes con dos empresas y al menos 100 viajes en total
  SELECT ZONA, ANIO, MES
  FROM por_mes
  GROUP BY ZONA, ANIO, MES
  HAVING COUNT(*) = 2 AND SUM(VIAJES) >= 100
),
cuota AS (
  SELECT p.ZONA, p.ANIO, p.MES, p.EMPRESA,
         100.0 * p.VIAJES / SUM(p.VIAJES) OVER (PARTITION BY p.ZONA, p.ANIO, p.MES) AS CUOTA
  FROM por_mes p
  JOIN con_dos c USING (ZONA, ANIO, MES)
),
variacion AS (
  SELECT ZONA, ANIO, MES, EMPRESA, CUOTA,
         ANIO * 12 + MES AS PERIODO,
         LAG(ANIO * 12 + MES) OVER (PARTITION BY ZONA, EMPRESA ORDER BY ANIO, MES) AS PERIODO_ANTERIOR,
         LAG(CUOTA)           OVER (PARTITION BY ZONA, EMPRESA ORDER BY ANIO, MES) AS CUOTA_MES_ANTERIOR
  FROM cuota
)
SELECT ZONA,
       EMPRESA,
       ANIO,
       MES,
       ROUND(CUOTA_MES_ANTERIOR, 2)         AS CUOTA_ANTERIOR,
       ROUND(CUOTA, 2)                      AS CUOTA,
       ROUND(CUOTA - CUOTA_MES_ANTERIOR, 2) AS VARIACION_PUNTOS,
       CASE WHEN CUOTA > 70 THEN 'sube por encima de 70' ELSE 'baja a 70 o menos' END AS CRUCE
FROM variacion
WHERE PERIODO - PERIODO_ANTERIOR = 1
  AND (CUOTA > 70) <> (CUOTA_MES_ANTERIOR > 70)
ORDER BY ZONA, EMPRESA, ANIO, MES;

-- Interpretación: Con al menos 100 viajes por zona-mes, hubo 49 cruces del 70 %: 33 subidas y 16 bajas.
-- Todos son de Uber, porque Lyft tiene alrededor de 30 % en todas las zonas y nunca se acerca al umbral.
-- Las subidas se concentran en febrero (31 zonas), y en marzo 16 zonas bajan y solo 2 suben. Esto coincide
-- con el crecimiento de Lyft en marzo (A1). Las variaciones son pequeñas (la mayoría entre 1 y 3 puntos),
-- porque muchas zonas están cerca del 70 %.
-- Lo que no dice: el umbral de 70 % lo fijó el enunciado; con tres meses no se sabe si el patrón se mantiene.


