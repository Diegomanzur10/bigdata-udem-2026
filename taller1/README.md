# Taller 1 · Una estrella en Snowflake para la pregunta de la lluvia en NYC

**Módulo de Big Data e Ingeniería de Datos (Universidad de Medellín)**  
**Equipo de Analítica:** Autoridad de Movilidad de NYC  


## 1. Integrantes y Roles del Equipo

*   **Valentina Restrepo Arboleda**
*   **Andres Fernando Molina Orozco**
  
| Rol | Responsable |
|---|---|
| Analista | Valentina Restrepo Arboleda |
| Modelador | Andres Fernando Molina Orozco |
| Ingeniero de datos | Valentina Restrepo Arboleda |
| Calidad y costos | Andres Fernando Molina Orozco |


## 2. Contexto y Objetivos del Taller

El objetivo principal de este taller consiste en procesar y analizar los viajes históricos de plataformas de transporte (Uber y Lyft) en la ciudad de Nueva York (NYC), resumidos por día, zona y empresa entre enero y marzo de 2024. 

Para cumplir con este propósito técnico y de negocio, el trabajo se estructuró en cuatro pilares fundamentales ejecutados sobre GitHub y Snowsight:
1.  **Diseño de un modelo estrella:** Definición de una tabla de hechos y sus respectivas dimensiones con un grano establecido (Una fila por fecha, zona y empresa).
2.  **Carga reproducible en Snowflake:** Poblado de las tablas en el esquema `CURSO.T1` con validación estricta de conteos de control frente al paquete original de datos.
3.  **Resolución analítica de preguntas (Caso A):** Implementación de funciones de ventana analítica (`RANK`, `QUALIFY`, `LAG`, agregaciones particionadas) enfocadas en la competencia entre plataformas.
4.  **Comunicación ejecutiva:** Redacción de un memo estratégico para una audiencia no técnica y reporte detallado de costos computacionales.


## 3. Elección del Caso: Caso A · Competencia entre plataformas

El equipo seleccionó el **Caso A**, centrado en la pregunta guía: *¿Hay concentración en el mercado de viajes por zona y cómo evoluciona?*
*   **Alcance analítico:** Estudio del comportamiento de Uber frente a Lyft en términos de volumen de viajes, ingresos, propinas ponderadas, concentración de mercado por zona y variaciones mensuales de participación mediante funciones de ventana.


## 4. El Modelo Estrella y su Grano

*   **Grano:** Una fila por fecha, zona y empresa.
*   **Tablas que componen la estrella:**
    *   `FACT_VIAJES_DIA`: Tabla central de hecho que almacena las métricas de negocio aditivas (`VIAJES`, `INGRESO_TOTAL`, `PROPINA_TOTAL`, `DISTANCIA_TOTAL`).
    *   `DIM_FECHA`: Dimensión de tiempo que incluye el año, mes, nombre del día de la semana, indicadores booleanos de fin de semana y festivo, y el registro único de lluvia diaria (`LLUVIA_MM`)
    *   `DIM_ZONA`: Dimensión geográfica depurada que unifica distritos (`BOROUGH`) y zonas de servicio (`SERVICE_ZONE`) resolviendo duplicidades de nombres.
    *   `DIM_EMPRESA`: Dimensión categórica construida mediante `SELECT DISTINCT` para las plataformas operativas.


## 5. Resumen de Entregables Ubicados en el Repositorio (`taller1/`)

*   `01_estrella.sql`: DDL completo de la estrella con restricción de llaves primarias, foráneas y definición explícita del grano.
*   `diagrama.md` / `diagrama.png`: Representación visual de la arquitectura relacional en estrella.
*   `02_carga.sql`: Carga reproducible e idempotente de las dimensiones y de la tabla de hechos con validación de conteo de control (46,715 filas y 60,268,466 viajes).
*   `03_preguntas.sql`: Desarrollo técnico de las cinco preguntas del Caso A utilizando técnicas de ventana y comentarios interpretativos.
*   `04_chequeos.sql`: Suite de validación de integridad (conteo de filas, unicidad de grano, ausencia de huérfanos y reconciliación de viajes).
*   `memo.md`: Documento ejecutivo de una página dirigido a la autoridad de movilidad, exponiendo hallazgos, supuestos, manejo de la trampa de promedios y límites analíticos.
*   `costos.md`: Reporte de créditos de Snowflake consumidos y análisis del operador más costoso en el *Query Profile*.
*   `RETOS.md`: Registro de los retos opcionales implementados.
*   `autoverificacion.txt`: Salida oficial obtenida al ejecutar el script de verificación.
