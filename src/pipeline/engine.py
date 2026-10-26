"""Creación de la SparkSession según el motor elegido (--engine).

- local: SparkSession local[*] con 2 GB de driver.
- glue: GlueContext sobre el SparkContext del job (si awsglue no está, SparkSession genérica).
- snowpark_connect: Snowpark Connect for Spark; warehouse y database vienen de la conexión
  de Snowflake, no se configuran aquí.
"""

from __future__ import annotations

import logging

from pyspark.sql import SparkSession

MOTORES = ("local", "glue", "snowpark_connect")
log = logging.getLogger(__name__)


def get_spark(engine: str) -> SparkSession:
    if engine not in MOTORES:
        raise ValueError(f"Motor desconocido '{engine}'. Válidos: {', '.join(MOTORES)}")
    if engine == "local":
        spark = _local()
    elif engine == "glue":
        spark = _glue()
    else:
        spark = _snowpark_connect()
    _configurar(spark)
    return spark


def _local() -> SparkSession:
    return (
        SparkSession.builder.master("local[*]")
        .appName("pipeline-taxi")
        .config("spark.driver.memory", "2g")
        .getOrCreate()
    )


def _glue() -> SparkSession:
    try:
        from awsglue.context import GlueContext
        from pyspark.context import SparkContext
    except ImportError:
        log.warning("awsglue no disponible: se usa una SparkSession genérica")
        return SparkSession.builder.getOrCreate()
    return GlueContext(SparkContext.getOrCreate()).spark_session


def _snowpark_connect() -> SparkSession:
    # Import perezoso: solo existe dentro del entorno de Snowflake.
    from snowflake import snowpark_connect

    spark = snowpark_connect.init_spark_session()
    if spark is None:
        spark = SparkSession.builder.getOrCreate()
    return spark


def _configurar(spark: SparkSession) -> None:
    """Zona horaria UTC (las fechas TLC son hora local sin offset) y overwrite dinámico."""
    try:
        spark.conf.set("spark.sql.session.timeZone", "UTC")
        spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
    except Exception as exc:  # algunos motores no permiten cambiar la configuración
        log.warning("No se pudo ajustar la configuración de Spark: %s", exc)
