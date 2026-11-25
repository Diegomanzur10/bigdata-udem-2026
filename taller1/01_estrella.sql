-- GRANO: una fila por fecha, zona de recogida y empresa (un día, una zona y una plataforma).
-- =====================================================================
-- TALLER 1 · 01_estrella.sql · DDL de la estrella
-- Equipo: Natasha Orozco, Miguel Angel Vélez, Xiomy Baquero · Anfitriona: Natasha Orozco · Caso: A
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
CREATE SCHEMA IF NOT EXISTS CURSO.T1;
USE SCHEMA CURSO.T1;

-- Dimensiones primero (el hecho apunta a ellas).

CREATE OR REPLACE TABLE DIM_EMPRESA (
  EMPRESA_KEY NUMBER(38,0) NOT NULL,
  EMPRESA     VARCHAR      NOT NULL,
  CONSTRAINT PK_DIM_EMPRESA PRIMARY KEY (EMPRESA_KEY)
);

CREATE OR REPLACE TABLE DIM_ZONA (
  ZONA_KEY     NUMBER(38,0) NOT NULL,
  ZONA         VARCHAR      NOT NULL,
  BOROUGH      VARCHAR,
  SERVICE_ZONE VARCHAR,
  CONSTRAINT PK_DIM_ZONA PRIMARY KEY (ZONA_KEY)
);

CREATE OR REPLACE TABLE DIM_FECHA (
  FECHA            DATE    NOT NULL,
  ANIO             NUMBER(4,0),
  MES              NUMBER(2,0),
  DIA_SEMANA       VARCHAR,
  ES_FIN_DE_SEMANA BOOLEAN,
  ES_FESTIVO       BOOLEAN,
  LLUVIA_MM        FLOAT,
  CONSTRAINT PK_DIM_FECHA PRIMARY KEY (FECHA)
);

-- Hecho: solo llaves y medidas aditivas. La lluvia no va aquí.
-- PROPINA_TOTAL = PROPINA_PROMEDIO x VIAJES; DISTANCIA_TOTAL = DISTANCIA_PROMEDIO x VIAJES.

CREATE OR REPLACE TABLE FACT_VIAJES_DIA (
  FECHA           DATE         NOT NULL,
  ZONA_KEY        NUMBER(38,0) NOT NULL,
  EMPRESA_KEY     NUMBER(38,0) NOT NULL,
  VIAJES          NUMBER(38,0),
  INGRESO_TOTAL   FLOAT,
  PROPINA_TOTAL   FLOAT,
  DISTANCIA_TOTAL FLOAT,
  CONSTRAINT FK_FECHA   FOREIGN KEY (FECHA)       REFERENCES DIM_FECHA (FECHA),
  CONSTRAINT FK_ZONA    FOREIGN KEY (ZONA_KEY)    REFERENCES DIM_ZONA (ZONA_KEY),
  CONSTRAINT FK_EMPRESA FOREIGN KEY (EMPRESA_KEY) REFERENCES DIM_EMPRESA (EMPRESA_KEY)
);

-- Claves (una línea por dimensión):
--   DIM_EMPRESA: EMPRESA_KEY, un número por empresa. Única porque cada nombre de empresa recibe una sola clave.
--   DIM_ZONA:    ZONA_KEY, un número por nombre de zona (262). Única porque cada nombre recibe una sola clave; se une por nombre, no por LocationID.
--   DIM_FECHA:   FECHA, un día por fila. Única porque se genera un solo registro por día.

-- Verificación rápida: deben aparecer las cuatro tablas.
SHOW TABLES IN SCHEMA CURSO.T1;
