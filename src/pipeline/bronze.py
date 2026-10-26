"""Capa bronze: descarga de fuentes SIN transformar.

Fuentes:
- NYC TLC yellow trips (Parquet mensual).
- NYC taxi zone lookup (CSV).
- Open-Meteo archive API (JSON diario, NYC).

local / dev / glue: se descarga con urllib en el driver y se publica en la ruta de config:
ruta local, o s3:// mediante boto3.
snowpark_connect: se descarga a un directorio temporal y se guarda como tabla BRONZE.* con Spark.
"""

from __future__ import annotations

import logging
import shutil
import tempfile
import urllib.request
from pathlib import Path
from typing import Any

from pipeline import io
from pipeline.settings import ultimo_dia_mes

log = logging.getLogger(__name__)

URL_VIAJES = "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_{mes}.parquet"
URL_ZONAS = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"
URL_CLIMA = (
    "https://archive-api.open-meteo.com/v1/archive"
    "?latitude=40.71&longitude=-74.01"
    "&start_date={inicio}&end_date={fin}"
    "&daily=precipitation_sum,temperature_2m_mean"
    "&timezone=America%2FNew_York"
)
TIMEOUT_S = 120


def url_clima(mes: str) -> str:
    inicio = f"{mes}-01"
    fin = ultimo_dia_mes(mes).isoformat()
    return URL_CLIMA.format(inicio=inicio, fin=fin)


def descargar(url: str, destino: str) -> str:
    """Descarga url y la publica en destino (ruta local o s3://). Devuelve destino."""
    with tempfile.TemporaryDirectory(prefix="bronze-") as tmp:
        local = _bajar(url, Path(tmp) / "archivo")
        _publicar(local, destino)
    log.info("Bronze escrito en %s", destino)
    return destino


def _bajar(url: str, destino_local: Path) -> Path:
    log.info("Descargando %s", url)
    with urllib.request.urlopen(url, timeout=TIMEOUT_S) as resp, destino_local.open("wb") as f:
        shutil.copyfileobj(resp, f)
    return destino_local


def _publicar(local: Path, destino: str) -> None:
    if destino.startswith("s3://"):
        import boto3  # import perezoso: solo se necesita al escribir en S3

        bucket, _, key = destino[len("s3://") :].partition("/")
        boto3.client("s3").upload_file(str(local), bucket, key)
    else:
        Path(destino).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(local, destino)


def main(spark: Any, cfg: dict, args: Any) -> None:
    mes = args.mes
    if args.engine == io.SNOWPARK:
        _cargar_snowpark(spark, mes)
        return
    descargar(URL_VIAJES.format(mes=mes), io.ruta_bronze_viajes(cfg, mes))
    descargar(URL_ZONAS, io.ruta_bronze_zonas(cfg))
    descargar(url_clima(mes), io.ruta_bronze_clima(cfg, mes))


def _cargar_snowpark(spark: Any, mes: str) -> None:
    with tempfile.TemporaryDirectory(prefix="bronze-") as tmp:
        d = Path(tmp)
        viajes = _bajar(URL_VIAJES.format(mes=mes), d / "viajes.parquet")
        io.escribir_tabla(spark.read.parquet(str(viajes)), "bronze_viajes")
        zonas = _bajar(URL_ZONAS, d / "zonas.csv")
        io.escribir_tabla(spark.read.option("header", True).csv(str(zonas)), "bronze_zonas")
        clima = _bajar(url_clima(mes), d / "clima.json")
        io.escribir_tabla(spark.read.option("multiLine", True).json(str(clima)), "bronze_clima")
