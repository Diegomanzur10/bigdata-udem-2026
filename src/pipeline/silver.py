"""Capa silver: limpieza de viajes y enriquecimiento con zonas y clima.

Funciones puras (DataFrame -> DataFrame): limpiar_viajes, clima_diario, enriquecer.
main(spark, cfg, args) lee bronze, transforma, valida y escribe silver particionado por pickup_date.
"""

from __future__ import annotations

from typing import Any

from pyspark.sql import DataFrame
from pyspark.sql import functions as F

from pipeline import io, quality
from pipeline.settings import inicio_fin_mes

DISTANCIA_MAX_MI = 100.0  # trip_distance está en millas
DURACION_MIN_MIN = 1.0
DURACION_MAX_MIN = 180.0


def limpiar_viajes(trips: DataFrame, mes: str | None = None) -> DataFrame:
    """Tipos, duración y filtros de outliers.

    Filtros: distancia > 0 y < 100 mi, tarifa > 0, duración entre 1 y 180 min,
    pickup dentro del mes (si se indica `mes`) y ubicación de recogida no nula.
    Agrega pickup_date (fecha de recogida, clave de partición).
    """
    base = trips.select(
        F.to_timestamp("tpep_pickup_datetime").alias("pickup_datetime"),
        F.to_timestamp("tpep_dropoff_datetime").alias("dropoff_datetime"),
        F.col("PULocationID").cast("int").alias("pu_location_id"),
        F.col("DOLocationID").cast("int").alias("do_location_id"),
        F.col("trip_distance").cast("double"),
        F.col("fare_amount").cast("double"),
        F.col("tip_amount").cast("double"),
        F.col("total_amount").cast("double"),
    ).withColumn(
        "duracion_min",
        (F.unix_timestamp("dropoff_datetime") - F.unix_timestamp("pickup_datetime")) / 60.0,
    )

    condicion = (
        F.col("pickup_datetime").isNotNull()
        & F.col("pu_location_id").isNotNull()
        & (F.col("trip_distance") > 0)
        & (F.col("trip_distance") < DISTANCIA_MAX_MI)
        & (F.col("fare_amount") > 0)
        & F.col("duracion_min").between(DURACION_MIN_MIN, DURACION_MAX_MIN)
    )
    if mes is not None:
        inicio, fin = inicio_fin_mes(mes)
        condicion = (
            condicion
            & (F.col("pickup_datetime") >= F.lit(inicio.isoformat()).cast("timestamp"))
            & (F.col("pickup_datetime") < F.lit(fin.isoformat()).cast("timestamp"))
        )

    return base.where(condicion).withColumn("pickup_date", F.to_date("pickup_datetime"))


def clima_diario(clima_raw: DataFrame) -> DataFrame:
    """Aplana el bloque 'daily' de Open-Meteo a filas (fecha, lluvia_mm, temp_media_c)."""
    # posexplode + element_at en lugar de explode(arrays_zip(...alias...)): Snowpark Connect
    # nombra los campos del struct "time AS fecha" y d.fecha deja de resolverse.
    base = clima_raw.select(
        F.posexplode(F.col("daily.time")).alias("i", "fecha"),
        F.col("daily.precipitation_sum").alias("lluvia"),
        F.col("daily.temperature_2m_mean").alias("temp"),
    )
    return base.select(
        F.to_date("fecha").alias("fecha"),
        F.element_at("lluvia", F.col("i") + 1).cast("double").alias("lluvia_mm"),
        F.element_at("temp", F.col("i") + 1).cast("double").alias("temp_media_c"),
    )


def enriquecer(trips: DataFrame, zonas: DataFrame, clima: DataFrame) -> DataFrame:
    """Une zona (por PULocationID) y clima (por pickup_date). Left joins: no pierde viajes.

    zona = nombre de la zona de recogida; si no está en el lookup, 'Zona <id>'.
    """
    zonas_sel = zonas.select(
        F.col("LocationID").cast("int").alias("pu_location_id"),
        F.col("Borough").alias("borough"),
        F.col("Zone").alias("zone_name"),
    )
    clima_sel = clima.select(F.col("fecha").alias("pickup_date"), "lluvia_mm", "temp_media_c")
    return (
        trips.join(F.broadcast(zonas_sel), "pu_location_id", "left")
        .join(F.broadcast(clima_sel), "pickup_date", "left")
        .withColumn(
            "zona",
            F.coalesce(
                F.col("zone_name"),
                F.concat(F.lit("Zona "), F.col("pu_location_id").cast("string")),
            ),
        )
        .drop("zone_name")
    )


def main(spark: Any, cfg: dict, args: Any) -> None:
    mes = args.mes
    viajes = io.leer_bronze_viajes(spark, cfg, args.engine, mes)
    max_rows = (cfg.get("muestra") or {}).get("max_rows")
    if max_rows:
        viajes = viajes.limit(int(max_rows))  # muestra local: primeras N filas del bronze

    zonas = io.leer_bronze_zonas(spark, cfg, args.engine)
    clima = clima_diario(io.leer_bronze_clima(spark, cfg, args.engine, mes))

    silver = enriquecer(limpiar_viajes(viajes, mes), zonas, clima)
    quality.validar(
        silver,
        nombre="silver",
        llaves=("pickup_datetime", "pickup_date", "pu_location_id", "zona"),
        rangos={
            "trip_distance": (0, DISTANCIA_MAX_MI),
            "fare_amount": (0, None),
            "duracion_min": (DURACION_MIN_MIN, DURACION_MAX_MIN),
        },
    )
    io.escribir_silver(silver, cfg, args.engine)
