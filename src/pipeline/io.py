"""Lectura y escritura de capas según el motor.

- local / glue: archivos en las rutas de config/<env>.yaml (rutas.bronze|silver|gold).
  silver se particiona por pickup_date (overwrite dinámico por partición). gold se particiona
  por mes (carpeta mes=YYYY-MM, columna derivada de fecha que NO queda dentro de los Parquet):
  la columna `fecha` sí queda en los archivos, porque Snowflake los carga con
  MATCH_BY_COLUMN_NAME (airflow/dags/sql/copy_gold.sql) y no lee columnas de partición.
- snowpark_connect: tablas BIGDATA.<CAPA>.<TABLA>:
    BRONZE.YELLOW_TRIPDATA, BRONZE.TAXI_ZONES, BRONZE.CLIMA_RAW,
    SILVER.YELLOW_TRIPS, GOLD.DAILY_ZONE_METRICS.
  Las tablas se sobrescriben completas, por eso en este motor se procesa un mes por ejecución.
"""

from __future__ import annotations

from pyspark.sql import DataFrame, SparkSession
from pyspark.sql import functions as F

from pipeline.settings import inicio_fin_mes

SNOWPARK = "snowpark_connect"
PREFIJO_TABLAS = "BIGDATA"
TABLAS = {
    "bronze_viajes": ("BRONZE", "YELLOW_TRIPDATA"),
    "bronze_zonas": ("BRONZE", "TAXI_ZONES"),
    "bronze_clima": ("BRONZE", "CLIMA_RAW"),
    "silver": ("SILVER", "YELLOW_TRIPS"),
    "gold": ("GOLD", "DAILY_ZONE_METRICS"),
}
CARPETA_CAPA = {"silver": "yellow_trips", "gold": "daily_zone_metrics"}


def nombre_tabla(clave: str) -> str:
    capa, tabla = TABLAS[clave]
    return f"{PREFIJO_TABLAS}.{capa}.{tabla}"


def _unir(base: str, *partes: str) -> str:
    return "/".join([base.rstrip("/"), *partes])


# --- rutas bronze (también usadas por bronze.py) ---------------------------------------------


def ruta_bronze_viajes(cfg: dict, mes: str) -> str:
    return _unir(cfg["rutas"]["bronze"], "yellow", f"mes={mes}", f"yellow_tripdata_{mes}.parquet")


def ruta_bronze_zonas(cfg: dict) -> str:
    return _unir(cfg["rutas"]["bronze"], "taxi_zones", "taxi_zone_lookup.csv")


def ruta_bronze_clima(cfg: dict, mes: str) -> str:
    return _unir(cfg["rutas"]["bronze"], "clima", f"mes={mes}", f"open_meteo_{mes}.json")


# --- lectura ----------------------------------------------------------------------------------


def leer_bronze_viajes(spark: SparkSession, cfg: dict, engine: str, mes: str) -> DataFrame:
    if engine == SNOWPARK:
        return spark.table(nombre_tabla("bronze_viajes"))
    return spark.read.parquet(ruta_bronze_viajes(cfg, mes))


def leer_bronze_zonas(spark: SparkSession, cfg: dict, engine: str) -> DataFrame:
    if engine == SNOWPARK:
        return spark.table(nombre_tabla("bronze_zonas"))
    return spark.read.option("header", True).csv(ruta_bronze_zonas(cfg))


def leer_bronze_clima(spark: SparkSession, cfg: dict, engine: str, mes: str) -> DataFrame:
    """JSON crudo de Open-Meteo (objeto con bloque 'daily')."""
    if engine == SNOWPARK:
        return spark.table(nombre_tabla("bronze_clima"))
    return spark.read.option("multiLine", True).json(ruta_bronze_clima(cfg, mes))


def leer_silver(spark: SparkSession, cfg: dict, engine: str, mes: str) -> DataFrame:
    """Silver filtrado al mes indicado (partition pruning en archivos)."""
    if engine == SNOWPARK:
        df = spark.table(nombre_tabla("silver"))
    else:
        df = spark.read.parquet(_unir(cfg["rutas"]["silver"], CARPETA_CAPA["silver"]))
    inicio, fin = inicio_fin_mes(mes)
    return df.where((F.col("pickup_date") >= F.lit(inicio)) & (F.col("pickup_date") < F.lit(fin)))


# --- escritura --------------------------------------------------------------------------------


def escribir_tabla(df: DataFrame, clave: str) -> None:
    """Guarda como tabla BIGDATA.<CAPA>.<TABLA> (sobrescribe)."""
    df.write.mode("overwrite").saveAsTable(nombre_tabla(clave))


def escribir_silver(df: DataFrame, cfg: dict, engine: str) -> None:
    _escribir(df, cfg, engine, "silver", "pickup_date")


def escribir_gold(df: DataFrame, cfg: dict, engine: str) -> None:
    if engine != SNOWPARK:
        df = df.withColumn("mes", F.date_format("fecha", "yyyy-MM"))
    _escribir(df, cfg, engine, "gold", "mes")


def _escribir(df: DataFrame, cfg: dict, engine: str, capa: str, particion: str) -> None:
    if engine == SNOWPARK:
        escribir_tabla(df, capa)
        return
    ruta = _unir(cfg["rutas"][capa], CARPETA_CAPA[capa])
    df.write.mode("overwrite").partitionBy(particion).parquet(ruta)
