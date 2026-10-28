"""Genera las muestras pequeñas de tests/data (determinista, sin red).

Uso: python tests/make_samples.py

Salida:
- yellow_tripdata_sample.csv: 100 viajes con columnas del esquema NYC TLC yellow
  (90 válidos de enero 2024 + 10 outliers que deben filtrarse).
- taxi_zone_lookup_sample.csv: subconjunto de zonas con los IDs reales.
- open_meteo_sample.json: 31 días de enero 2024 con el formato de la archive API.

Los datos son sintéticos: solo imitan el esquema, no son datos oficiales.
"""

from __future__ import annotations

import csv
import json
import random
from datetime import datetime, timedelta
from pathlib import Path

DATA = Path(__file__).resolve().parent / "data"
SEMILLA = 20240101
ID_FUERA_DE_LOOKUP = 250  # ID de zona sin fila en el lookup (prueba el fallback)

ZONAS = [
    (1, "EWR", "Newark Airport", "EWR"),
    (4, "Manhattan", "Alphabet City", "Yellow Zone"),
    (12, "Manhattan", "Battery Park", "Yellow Zone"),
    (13, "Manhattan", "Battery Park City", "Yellow Zone"),
    (43, "Manhattan", "Central Park", "Yellow Zone"),
    (48, "Manhattan", "Clinton East", "Yellow Zone"),
    (79, "Manhattan", "East Village", "Yellow Zone"),
    (132, "Queens", "JFK Airport", "Airports"),
    (161, "Manhattan", "Midtown Center", "Yellow Zone"),
    (230, "Manhattan", "Times Sq/Theatre District", "Yellow Zone"),
    (236, "Manhattan", "Upper East Side North", "Yellow Zone"),
    (237, "Manhattan", "Upper East Side South", "Yellow Zone"),
]

COLUMNAS_TRIPS = [
    "VendorID",
    "tpep_pickup_datetime",
    "tpep_dropoff_datetime",
    "passenger_count",
    "trip_distance",
    "RatecodeID",
    "store_and_fwd_flag",
    "PULocationID",
    "DOLocationID",
    "payment_type",
    "fare_amount",
    "extra",
    "mta_tax",
    "tip_amount",
    "tolls_amount",
    "improvement_surcharge",
    "total_amount",
    "congestion_surcharge",
    "airport_fee",
]


def _fila(
    rng: random.Random,
    pickup: datetime,
    dropoff: datetime | None,
    distancia: float,
    pu: int | None,
    do: int,
    tarifa: float,
    propina: float,
) -> dict:
    total = round(tarifa + 1.0 + 0.5 + propina + 0.0 + 1.0 + 2.5, 2)
    fmt = "%Y-%m-%d %H:%M:%S"
    return {
        "VendorID": rng.choice([1, 2]),
        "tpep_pickup_datetime": pickup.strftime(fmt),
        "tpep_dropoff_datetime": dropoff.strftime(fmt) if dropoff else "",
        "passenger_count": 1,
        "trip_distance": distancia,
        "RatecodeID": 1,
        "store_and_fwd_flag": "N",
        "PULocationID": "" if pu is None else pu,
        "DOLocationID": do,
        "payment_type": 1,
        "fare_amount": tarifa,
        "extra": 1.0,
        "mta_tax": 0.5,
        "tip_amount": propina,
        "tolls_amount": 0.0,
        "improvement_surcharge": 1.0,
        "total_amount": total,
        "congestion_surcharge": 2.5,
        "airport_fee": 0.0,
    }


def generar_viajes(rng: random.Random) -> list[dict]:
    ids = [z[0] for z in ZONAS] + [ID_FUERA_DE_LOOKUP]
    filas = []
    inicio = datetime(2024, 1, 1)
    for i in range(90):  # válidos: todos con recogida dentro de enero 2024
        pickup = inicio + timedelta(
            days=rng.randrange(31), hours=rng.randrange(24), minutes=rng.randrange(60)
        )
        duracion = rng.randint(3, 90)
        distancia = round(rng.uniform(0.4, 25.0), 2)
        tarifa = round(3.0 + 2.5 * distancia + rng.uniform(0, 3), 2)
        propina = round(tarifa * rng.uniform(0, 0.3), 2)
        filas.append(
            _fila(
                rng,
                pickup,
                pickup + timedelta(minutes=duracion),
                distancia,
                ids[i % len(ids)],
                rng.choice(ids),
                tarifa,
                propina,
            )
        )

    base = datetime(2024, 1, 15, 12, 0)
    outliers = [
        _fila(rng, base, base + timedelta(minutes=20), 0.0, 43, 79, 12.5, 2.0),  # distancia 0
        _fila(rng, base, base + timedelta(minutes=50), 150.0, 43, 79, 60.0, 5.0),  # distancia>=100
        _fila(rng, base, base + timedelta(minutes=20), 3.2, 43, 79, -2.5, 0.0),  # tarifa < 0
        _fila(rng, base, base + timedelta(minutes=20), 3.2, 43, 79, 0.0, 0.0),  # tarifa = 0
        _fila(rng, base, base, 2.0, 43, 79, 10.0, 1.0),  # duración 0 min
        _fila(rng, base, base + timedelta(minutes=240), 30.0, 132, 1, 70.0, 0.0),  # duración>180
        _fila(  # recogida antes del mes
            rng,
            datetime(2023, 12, 31, 23, 50),
            datetime(2024, 1, 1, 0, 10),
            2.0,
            43,
            79,
            9.0,
            1.0,
        ),
        _fila(  # recogida después del mes
            rng,
            datetime(2024, 2, 1, 0, 5),
            datetime(2024, 2, 1, 0, 25),
            2.0,
            43,
            79,
            9.0,
            1.0,
        ),
        _fila(rng, base, base + timedelta(minutes=15), 2.0, None, 79, 9.0, 1.0),  # PU nulo
        _fila(rng, base, None, 2.0, 43, 79, 9.0, 1.0),  # dropoff nulo
    ]
    return filas + outliers


def generar_clima(rng: random.Random) -> dict:
    dias = [datetime(2024, 1, 1) + timedelta(days=d) for d in range(31)]
    lluvia = [round(rng.uniform(0, 12), 1) if rng.random() < 0.4 else 0.0 for _ in dias]
    temp = [round(rng.uniform(-3, 9), 1) for _ in dias]
    return {
        "latitude": 40.71,
        "longitude": -74.01,
        "generationtime_ms": 0.5,
        "utc_offset_seconds": -18000,
        "timezone": "America/New_York",
        "timezone_abbreviation": "GMT-5",
        "elevation": 10.0,
        "daily_units": {
            "time": "iso8601",
            "precipitation_sum": "mm",
            "temperature_2m_mean": "celsius",
        },
        "daily": {
            "time": [d.strftime("%Y-%m-%d") for d in dias],
            "precipitation_sum": lluvia,
            "temperature_2m_mean": temp,
        },
    }


def main() -> None:
    DATA.mkdir(parents=True, exist_ok=True)
    rng = random.Random(SEMILLA)

    viajes = generar_viajes(rng)
    with (DATA / "yellow_tripdata_sample.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNAS_TRIPS)
        w.writeheader()
        w.writerows(viajes)

    with (DATA / "taxi_zone_lookup_sample.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["LocationID", "Borough", "Zone", "service_zone"])
        w.writerows(ZONAS)

    clima = generar_clima(rng)
    (DATA / "open_meteo_sample.json").write_text(
        json.dumps(clima, indent=2) + "\n", encoding="utf-8"
    )
    print(f"viajes={len(viajes)} zonas={len(ZONAS)} dias_clima={len(clima['daily']['time'])}")


if __name__ == "__main__":
    main()
