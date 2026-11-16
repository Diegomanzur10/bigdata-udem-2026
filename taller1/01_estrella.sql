-- GRANO: una fila por fecha, zona y empresa
-- =====================================================================
-- TALLER 1 · 01_estrella.sql · DDL de la estrella (esqueleto)
-- Equipo: <VALENTINA RESTREPO ARBOLEDA, ANDRES FERNANDO MOLINA OROZCO> · Anfitrión: <VALENTINA RESTREPO ARBOLEDA (GIT:ValentinaRestrepo2)> · Caso elegido: <A>
-- =====================================================================
-- CÓMO USAR ESTE ARCHIVO
--   1. Copia esta carpeta (plantilla/) a taller1/ en el fork del anfitrión: Add file > Create new
--      file, o Upload files.
--   2. Reemplaza cada línea «TODO» por tu sentencia. Todo se crea en CURSO.T1, con estos nombres:
--      FACT_VIAJES_DIA, DIM_FECHA, DIM_ZONA y DIM_EMPRESA.
--   3. La primera línea de este archivo es el grano. Si cambias el grano sugerido, justifícalo en el memo.
--   4. Cada integrante corre este archivo y 02_carga.sql en su propia cuenta de Snowflake.
--
-- RECORDATORIOS DEL ENUNCIADO (taller1/README.md, secciones 3, 4 y 6)
--   - El hecho guarda medidas aditivas: VIAJES, INGRESO_TOTAL y las sumas que permiten rehacer los
--     promedios (promedio x viajes). La lluvia no va en el hecho.
--   - Cada dimensión tiene una clave única. DIM_ZONA del Lab 4 repite 2 nombres de zona: decide
--     cómo dejar una fila por nombre.
--   - DIM_EMPRESA se construye con SELECT DISTINCT; no escribas los nombres de las empresas a mano.
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
CREATE SCHEMA IF NOT EXISTS CURSO.T1;
USE SCHEMA CURSO.T1;

-- TODO · DIM_EMPRESA: clave y nombre de la empresa.
CREATE OR REPLACE TABLE DIM_EMPRESA (
    EMPRESA VARCHAR(10) PRIMARY KEY);

-- TODO · DIM_ZONA: clave única, zona, distrito (BOROUGH) y tipo de zona (SERVICE_ZONE).
CREATE OR REPLACE TABLE DIM_ZONA (    
    ZONA VARCHAR(100) PRIMARY KEY NOT NULL,
    BOROUGH VARCHAR(100),
    SERVICE_ZONE VARCHAR(100)
);

-- TODO · DIM_FECHA: un día por fila, con día de la semana, fin de semana, festivo y la lluvia del día.
CREATE OR REPLACE TABLE DIM_FECHA (
    FECHA DATE PRIMARY KEY,
    ANIO NUMBER(4) NOT NULL,
    MES NUMBER(2) NOT NULL,
    DIA_SEMANA VARCHAR(15) NOT NULL,
    ES_FIN_SEMANA BOOLEAN NOT NULL,
    ES_FESTIVO BOOLEAN NOT NULL,
    LLUVIA_MM FLOAT NOT NULL
);

-- TODO · FACT_VIAJES_DIA: las llaves de las dimensiones y las medidas aditivas.
CREATE OR REPLACE TABLE FACT_VIAJES_DIA ( FECHA DATE,
    ZONA VARCHAR(100),
    EMPRESA VARCHAR(10),
    VIAJES NUMBER,
    INGRESO_TOTAL FLOAT,
    PROPINA_PROMEDIO FLOAT,
    DISTANCIA_PROMEDIO FLOAT,
    
    FOREIGN KEY (FECHA)
        REFERENCES DIM_FECHA(FECHA),

    FOREIGN KEY (ZONA)
        REFERENCES DIM_ZONA(ZONA),

    FOREIGN KEY (EMPRESA)
        REFERENCES DIM_EMPRESA(EMPRESA) );

-- Claves (una línea por dimensión): cómo se une cada dimensión con el hecho y por qué esa clave es única.
--   DIM_EMPRESA: Se une por la columna de la tabla de hecho EMPRESA. Es una clave única debido a que solo se tienen dos registros únicos (Aplicaciones)
--   DIM_ZONA: Se une por la columna de la tabla de hecho ZONA. Es una clave única debido a que para BOROUGH y SERVICE_ZONE existe zonas unicas. (El problema de la tabla con zonas duplicadas se trata en la carga.sql)
--   DIM_FECHA: Se une por la columna de la tabla de hecho Date. Es una clave única debido a que la tabla DIM_FECHA solo se tiene un registro por día.
