-- =====================================================================
-- TALLER 1 · 03_preguntas.sql · Las cinco preguntas del caso (esqueleto)
-- =====================================================================
-- Caso elegido: <A · Competencia entre plataformas>
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
GROUP BY EMPRESA
ORDER BY EMPRESA;
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
QUALIFY RANK() OVER (PARTITION BY EMPRESA ORDER BY SUM(VIAJES) DESC) <= 3
ORDER BY EMPRESA, RANKING;
-- Interpretación: Se evidencia una convergencia estratégica entre Uber y Lyft, ya que ambas plataformas comparten exactamente las mismas tres zonas de mayor demanda en todo el primer trimestre de 2024: LaGuardia Airport, JFK Airport y el sector residencial y comercial de East Village; sin embargo, mientras que para Lyft el primer lugar lo lidera LaGuardia con cerca de 295 mil viajes, para Uber el nodo con mayor flujo es el aeropuerto JFK con una cifra masiva que supera los 810 mil viajes, lo que demuestra que si bien compiten en los mismos epicentros de transporte y movilidad de la ciudad, Uber opera a una escala de volumen significativamente mayor en los nodos aeroportuarios.

-- ---------------------------------------------------------------------
-- Pregunta 4: Cuota de mercado de cada empresa en cada zona y mes	
-- ---------------------------------------------------------------------
-- TODO · consulta
SELECT
    F.ANIO, F.MES,H.EMPRESA, H.ZONA, SUM(H.VIAJES) AS VIAJES_EMPRESA, (100*SUM(H.VIAJES)) /SUM(SUM(H.VIAJES))
    OVER (
        PARTITION BY F.ANIO, F.MES, H.ZONA
    ) AS CUOTA_MERCADO

FROM FACT_VIAJES_DIA H
LEFT JOIN DIM_FECHA F
    ON H.FECHA = F.FECHA
GROUP BY    
    F.ANIO,
    F.MES,
    H.ZONA,
    H.EMPRESA
ORDER BY CUOTA_MERCADO DESC, F.MES ASC, H.ZONA ASC, H.EMPRESA ASC;

-- Interpretación: 
--La consulta permite identificar la participación de mercado de cada empresa por zona y por mes durante el período analizado (enero, febrero y marzo). 
--El resultado es útil para evaluar el posicionamiento competitivo de cada empresa y apoyar en la toma de decisiones
--estratégicas orientadas a fortalecer la presencia en determinadas zonas de NYC.
--Se observa que en un número importante de zonas la mayor cuota de mercado corresponde a Uber. Lo que indica que la población de NYC prefiere usar la empresa UBER.
--Este resultado también puede permitir que la empresa Lyft identifique las zonas donde mantiene una mayor participación
--para enfocar esfuerzos comerciales y operativos que le permitan conservar la fidelidad de sus usuarios dependiendo de la zona. 
--De igual forma, los resultados ayudan a detectar aquellas zonas donde la participación es reducida, 
--facilitando la definición de estrategias para incrementar la demanda y mejorar su competitividad frente a otros operadores.

-- ---------------------------------------------------------------------
-- Pregunta 5: Variación mensual de la cuota y zonas donde una empresa pasa de 70 %
-- ---------------------------------------------------------------------

WITH CUOTA_MENSUAL AS (

    SELECT
        F.ANIO,
        F.MES,
        H.ZONA,
        H.EMPRESA,

        SUM(H.VIAJES) AS VIAJES_EMPRESA,

        SUM(H.VIAJES)
        / NULLIF(
            SUM(SUM(H.VIAJES)) OVER (
                PARTITION BY F.ANIO, F.MES, H.ZONA
            ),
            0
        ) AS CUOTA_MERCADO

    FROM FACT_VIAJES_DIA H
    LEFT JOIN DIM_FECHA F
        ON H.FECHA = F.FECHA

    GROUP BY
        F.ANIO,
        F.MES,
        H.ZONA,
        H.EMPRESA
)

SELECT
    ANIO,
    MES,
    ZONA,
    EMPRESA,

    ROUND(100*CUOTA_MERCADO,2) AS CUOTA_MERCADO,

    ROUND( LAG(CUOTA_MERCADO) OVER (
            PARTITION BY EMPRESA, ZONA
            ORDER BY ANIO, MES
        ) * 100, 2) AS CUOTA_MES_ANTERIOR,

    ROUND( 100*(CUOTA_MERCADO- LAG(CUOTA_MERCADO)
        OVER (  PARTITION BY EMPRESA, ZONA
                ORDER BY ANIO, MES)),4) AS VARIACION_CUOTA
FROM CUOTA_MENSUAL

QUALIFY
    LAG(CUOTA_MERCADO) OVER (
        PARTITION BY EMPRESA, ZONA
        ORDER BY ANIO, MES
    ) IS NOT NULL
    AND
    LAG(CUOTA_MERCADO) OVER (
        PARTITION BY EMPRESA, ZONA
        ORDER BY ANIO, MES
    ) < 0.70
    AND
    CUOTA_MERCADO >= 0.70

ORDER BY
    ANIO,
    MES,
    ZONA,
    EMPRESA;

-- Observacion: Enero al ser el primer mes no contiene datos para obtener una variacion. Por lo que este mes se excluye en el resultado final.
--Interpretacion: Un hallazgo relevante es que todos los casos corresponden a Uber, lo que indica UBER gana mayor participación del mercado 
--sobre su competidora plataforma Lyft durante febrero y marzo en 34 zonas. 
--Adicionalmente, 31 de los 34 registros se presentaron en el mes de febrero, mientras que los 3 restantes ocurrieron en marzo.
--El hecho de que la mayoría de los cruces del umbral del 70% se concentren en un único mes podría estar asociado a factores como 
--cambios en la demanda, estrategias comerciales, disponibilidad de vehículos, variaciones en precios o una reducción de la participación de sus competidores.
--Se necesita más información para identificar una causalidad.

