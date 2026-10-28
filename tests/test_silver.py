from __future__ import annotations

from pyspark.sql import functions as F

from pipeline.silver import clima_diario, enriquecer, limpiar_viajes

MES = "2024-01"

COLS_ENTRADA = [
    "tpep_pickup_datetime",
    "tpep_dropoff_datetime",
    "PULocationID",
    "DOLocationID",
    "trip_distance",
    "fare_amount",
    "tip_amount",
    "total_amount",
]


def _viaje(pickup, dropoff, pu=43, distancia=3.0, tarifa=12.0):
    return (pickup, dropoff, pu, 79, distancia, tarifa, 2.0, 16.0)


def test_limpiar_viajes_filtra_cada_tipo_de_outlier(spark):
    buena = _viaje("2024-01-10 10:00:00", "2024-01-10 10:20:00")
    malas = [
        _viaje("2024-01-10 10:00:00", "2024-01-10 10:20:00", distancia=0.0),
        _viaje("2024-01-10 10:00:00", "2024-01-10 10:20:00", distancia=100.0),
        _viaje("2024-01-10 10:00:00", "2024-01-10 10:20:00", tarifa=0.0),
        _viaje("2024-01-10 10:00:00", "2024-01-10 10:00:00"),  # 0 min
        _viaje("2024-01-10 10:00:00", "2024-01-10 13:01:00"),  # 181 min
        _viaje("2024-01-10 10:00:00", "2024-01-10 10:20:00", pu=None),
        _viaje("2023-12-31 23:50:00", "2024-01-01 00:10:00"),  # antes del mes
        _viaje("2024-02-01 00:05:00", "2024-02-01 00:25:00"),  # después del mes
    ]
    df = spark.createDataFrame([buena, *malas], COLS_ENTRADA)

    limpio = limpiar_viajes(df, MES).collect()

    assert len(limpio) == 1
    assert str(limpio[0]["pickup_date"]) == "2024-01-10"
    assert limpio[0]["duracion_min"] == 20.0


def test_limpiar_viajes_sin_mes_no_filtra_fechas(spark):
    df = spark.createDataFrame([_viaje("2023-12-31 23:50:00", "2024-01-01 00:10:00")], COLS_ENTRADA)
    assert limpiar_viajes(df).count() == 1
    assert limpiar_viajes(df, MES).count() == 0


def test_limpiar_viajes_muestra_csv(muestra_viajes):
    limpio = limpiar_viajes(muestra_viajes, MES)

    # 90 viajes válidos en la muestra; los 10 outliers se descartan
    assert limpio.count() == 90
    rangos = limpio.agg(
        F.min("trip_distance").alias("d_min"),
        F.max("trip_distance").alias("d_max"),
        F.min("duracion_min").alias("u_min"),
        F.max("duracion_min").alias("u_max"),
        F.min("fare_amount").alias("f_min"),
        F.min("pickup_date").alias("p_min"),
        F.max("pickup_date").alias("p_max"),
    ).first()
    assert 0 < rangos["d_min"] and rangos["d_max"] < 100
    assert 1 <= rangos["u_min"] and rangos["u_max"] <= 180
    assert rangos["f_min"] > 0
    assert str(rangos["p_min"]) >= "2024-01-01" and str(rangos["p_max"]) <= "2024-01-31"


def test_clima_diario_aplana_daily(muestra_clima_raw):
    clima = clima_diario(muestra_clima_raw)

    assert clima.columns == ["fecha", "lluvia_mm", "temp_media_c"]
    assert clima.count() == 31
    assert dict(clima.dtypes)["fecha"] == "date"


def test_enriquecer_conserva_filas_y_asigna_zona_y_lluvia(
    muestra_viajes, muestra_zonas, muestra_clima_raw
):
    trips = limpiar_viajes(muestra_viajes, MES)
    clima = clima_diario(muestra_clima_raw)

    silver = enriquecer(trips, muestra_zonas, clima)

    assert silver.count() == trips.count()  # left joins: no se pierden viajes
    fila_jfk = silver.where("pu_location_id = 132").select("zona", "borough").first()
    assert fila_jfk["zona"] == "JFK Airport"
    assert fila_jfk["borough"] == "Queens"

    fuera = silver.where("pu_location_id = 250").select("zona").first()
    assert fuera["zona"] == "Zona 250"

    # la lluvia de cada viaje es la del día de recogida
    esperada = clima.withColumnRenamed("fecha", "pickup_date")
    cruce = (
        silver.select("pickup_date", "lluvia_mm")
        .distinct()
        .join(
            esperada.select("pickup_date", F.col("lluvia_mm").alias("lluvia_esperada")),
            "pickup_date",
        )
    )
    assert cruce.where("lluvia_mm <> lluvia_esperada OR lluvia_mm IS NULL").count() == 0
