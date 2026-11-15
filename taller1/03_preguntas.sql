-- =====================================================================
-- TALLER 1 · 03_preguntas.sql · Las cinco preguntas del caso (esqueleto)
-- =====================================================================
-- Caso elegido: <A · Competencia entre plataformas | B · Clima y festivos | C · Aeropuertos y distritos>
-- Entre las cinco preguntas usa al menos: RANK con QUALIFY, LAG y una agregación de ventana
-- (SUM o AVG con OVER). Cada pregunta lleva su enunciado arriba, su consulta y, debajo, un
-- comentario que interprete el resultado (qué dice el número y qué no dice).
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- ---------------------------------------------------------------------
-- Pregunta 1: Ingresos y viajes por empresa y mes
-- ---------------------------------------------------------------------
-- TODO · consulta
SELECT 
    F.EMPRESA, 
    D.MES, 
    SUM(F.VIAJES) AS TOTAL_VIAJES, 
    ROUND(SUM(F.INGRESO_TOTAL), 2) AS TOTAL_INGRESOS
FROM FACT_VIAJES_DIA F
JOIN DIM_FECHA D ON F.FECHA = D.FECHA
GROUP BY F.EMPRESA, D.MES
ORDER BY F.EMPRESA, D.MES;
-- Interpretación: Los datos muestran que Uber dominó ampliamente el mercado de Nueva York durante el primer trimestre de 2024, triplicando a Lyft tanto en volumen de viajes (con más de 14 millones mensuales frente a los 4-5 millones de Lyft) como en ingresos totales, registrando además un aumento general de viajes en marzo para ambas plataformas; sin embargo, estas cifras no revelan las causas especificas de dicha brecha en la participación, las diferencias en las tarifas promedio por trayecto, los márgenes de ganancia, etc.

-- ---------------------------------------------------------------------
-- Pregunta 2: Propina promedio por empresa, ponderada por viajes
-- ---------------------------------------------------------------------
-- TODO · consulta
SELECT 
    EMPRESA, 
    ROUND(SUM(PROPINA_PROMEDIO * VIAJES) / SUM(VIAJES), 2) AS PROPINA_PROMEDIO_PONDERADA
FROM FACT_VIAJES_DIA
GROUP BY EMPRESA;
-- Interpretación: Los datos reflejan que Lyft (1.18) obtiene una propina promedio ponderada ligeramente superior a la de Uber (1.06) por viaje en el trimestre; no obstante, esta cifra solo muestra una diferencia en el comportamiento de agradecimiento de los usuarios entre ambas plataformas, pero no explica si se debe a diferencias en las tarifas base, la duración de los recorridos o la satisfacción con el servicio.

-- ---------------------------------------------------------------------
-- Pregunta 3: Las tres zonas con más viajes de cada empresa
-- ---------------------------------------------------------------------
-- TODO · consulta
SELECT 
    EMPRESA, 
    ZONA, 
    SUM(VIAJES) AS TOTAL_VIAJES,
    RANK() OVER (PARTITION BY EMPRESA ORDER BY SUM(VIAJES) DESC) AS RANKING
FROM FACT_VIAJES_DIA
GROUP BY EMPRESA, ZONA
QUALIFY RANKING <= 3;
-- Interpretación: Se evidencia una convergencia estratégica entre Uber y Lyft, ya que ambas plataformas comparten exactamente las mismas tres zonas de mayor demanda en todo el primer trimestre de 2024: LaGuardia Airport, JFK Airport y el sector residencial y comercial de East Village; sin embargo, mientras que para Lyft el primer lugar lo lidera LaGuardia con cerca de 295 mil viajes, para Uber el nodo con mayor flujo es el aeropuerto JFK con una cifra masiva que supera los 810 mil viajes, lo que demuestra que si bien compiten en los mismos epicentros de transporte y movilidad de la ciudad, Uber opera a una escala de volumen significativamente mayor en los nodos aeroportuarios.

-- ---------------------------------------------------------------------
-- Pregunta 4: <copia el enunciado>
-- ---------------------------------------------------------------------
-- TODO · consulta
-- Interpretación: <...>

-- ---------------------------------------------------------------------
-- Pregunta 5: <copia el enunciado>
-- ---------------------------------------------------------------------
-- TODO · consulta
-- Interpretación: <...>
