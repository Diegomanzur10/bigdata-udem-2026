# Contrato del Taller 2

Equipo: Propin AI · Anfitrión (dueño del fork): Valentina Restrepo Arboleda

## 1. Integrantes y roles

| Integrante | Rol en el Taller 1 | Rol en el Taller 2 |
|---|---|---|
| Valentina Restrepo Arboleda | Ingeniera de datos; calidad y costos | Analista de negocio y cumplimiento; modeladora SQL |
| Andrés Fernando Molina Orozco | Analista; modelador | Ingeniero de datos; operador cloud y calidad |

Somos dos integrantes, así que cada uno asume dos roles y nadie repite los del Taller 1.

## 2. Pregunta de negocio

> En enero de 2024, ¿el aumento de la propina en los días con lluvia, en los viajes de Uber o de Lyft, es mayor en las zonas de NYC donde esa plataforma concentra más del 70 % de los viajes que en las zonas donde ninguna de las dos supera ese umbral?

**Para quién es la respuesta y qué decisión apoyaría:** operaciones y mercadeo de Uber o Lyft, para decidir en qué zonas lanzar incentivos, promociones o bonos los días de lluvia.

## 3. Hipótesis

> En los viajes de cada plataforma, la propina como porcentaje de la tarifa sube los días con lluvia en los dos grupos de zonas, pero sube más en las zonas que esa plataforma domina, porque en una zona dominada el pasajero prefiere el servicio de esa plataforma y, cuando llueve, está dispuesto a dar más propina para que le llegue un carro de esa plataforma en concreto. La hipótesis es falsa si el aumento en las zonas dominadas no supera al de las no dominadas en al menos 0,5 puntos porcentuales, o si la propina no sube con la lluvia.

## 4. Cambio elegido

| Campo | Respuesta |
|---|---|
| Capa | silver y gold |
| Archivo y función donde va | src/pipeline/silver.py, dentro de `enriquecer`; src/pipeline/gold.py, función `propin_ai_propina_lluvia_zona`, y su CREATE TABLE en src/pipeline/carga.py |
| Qué se agrega o cambia | Columna DIA_LLUVIA en silver. Gold agrega por fecha, zona de recogida y empresa: DIA_LLUVIA, VIAJES, VIAJES_CON_PROPINA, PROPINA_TOTAL y TARIFA_BASE_TOTAL. Funciones que se completan: agregar_metadatos (bronze.py) y deduplicar (silver.py), con sus pruebas en OK. La función de gold se suma a TABLAS_GOLD y su tabla a TABLAS_A_CARGAR. |
| Definición exacta | DIA_LLUVIA: lluvia (más de 0 mm), seco (0 mm) y sin_dato (lluvia nula). VIAJES_CON_PROPINA: viajes con propina mayor a 0. |
| Por qué lo necesita la pregunta | El gold actual no separa los viajes por empresa ni guarda la propina por zona. |

## 5. Cómo se comprobará

- **Cifras de Athena:** COUNT(*) contra COUNT(DISTINCT _hash_fila) en silver, antes y después de deduplicar y tras reprocesar el mes.
- **Cifras de Snowflake:** conteo de viajes de la tabla del equipo por DIA_LLUVIA y por EMPRESA; conteo de días por valor de DIA_LLUVIA en enero de 2024 (con COUNT(DISTINCT FECHA), no filas); la suma de VIAJES contra las filas de silver de 2024-01.
- **Prueba en el cuaderno:** con limite="1000", un día con 0 mm queda seco, uno con más de 0 mm queda lluvia y uno sin clima queda sin_dato.
- **Corrida en Glue:** pipeline_taxi con computo=glue_small, limite=todos, mes=2024-01. Las pruebas de duplicados, con limite=1000 en 2024-01.
- **Evidencia de la corrida:** captura del DAG pipeline_taxi en el Airflow del Code Editor de la cuenta de la anfitriona, con las cuatro tareas en success y los parámetros computo, limite y mes visibles.
- **Costo:** créditos de Snowflake (consulta de costos.md del Taller 1 con la fecha ajustada) y tiempo de Glue por corrida; comparación de glue_small contra glue_medium; configuración que elegiríamos cada mes y por qué.
- **CI y revisión:** PR con los cinco checks del CI en verde antes del merge. Revisora del PR: Valentina Restrepo Arboleda (el cambio lo escribe Andrés).

## 6. Qué cifra responderá la pregunta

- **Tabla de donde sale:** BIGDATA.DEV.PROPIN_AI_PROPINA_LLUVIA_ZONA en Snowflake.
- **La cifra o comparación:** zona dominada: una plataforma tiene más del 70 % de los viajes de enero de 2024 (solo zonas con 1 000 o más viajes). Para Uber y para Lyft, porcentaje de propina (suma de propinas sobre suma de tarifas) en días con lluvia y secos, y su aumento en las zonas que domina frente a las que no domina nadie.
- **Cómo se leerá el resultado:** si el aumento en sus zonas dominadas es mayor en 0,5 puntos o más, la hipótesis se sostiene; si no, cae.
- **Conciliación prevista:** filas de bronze menos descartes de silver (contados por tipo) igual a filas de silver; filas de silver igual a SUM(VIAJES) de gold y de Snowflake.

## 7. Riesgos

| Riesgo | Cómo lo manejaremos |
|---|---|
| Pocos días con lluvia | Se reporta cuántos son (n). |
| Lluvia repetida en todas las filas del día | Se cuenta con COUNT(DISTINCT FECHA). |
| Duplicados al reprocesar | Sin deduplicar, cada reproceso multiplica los viajes; se escribe antes de correr el mes completo. |
| Presupuesto de Glue y Snowflake | Se prueba con limite=1000 en 2024-01 antes de limite=todos, y se apaga al terminar cada sesión (make airflow-off, make airflow-local-down y make estado). |
| El PR propone el repositorio del curso como destino | Cambiar base repository al fork del equipo. |
| El run de Glue no usa el cambio | Antes de lanzar, en la cuenta de la anfitriona: cd ~/bigdata && git switch main && git pull. |
| ColumnasDistintas en Snowflake | Ejecutar el ALTER TABLE que sugiere el error y volver a lanzar cargar_snowflake. |
| Tras el merge, la VM de prod puede quedar encendida | Apagarla con make airflow-off. |

## 8. Acuerdos de trabajo

- **Reunión del equipo (videollamada):** 26, 27 y 28 de noviembre, en horario diurno.
- **Comunicación del equipo:** WhatsApp.
- **Asesoría con el docente:** 28 de noviembre, 10:00 a. m.
- **Quién revisa los PR:** Valentina Restrepo revisa el PR del cambio que escribe Andrés Molina y viceversa; nadie aprueba su propio PR.
- **Cuándo se hace merge:** solo con CI en verde y una revisión.
- **Entrega:** release t2-entrega publicado el domingo 29 de noviembre de 2026, a las 12:00 (mediodía).

## 9. Cambios al contrato

| Fecha | Qué cambió | Por qué |
|---|---|---|
| | | |
