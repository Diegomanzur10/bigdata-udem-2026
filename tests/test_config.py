from __future__ import annotations

from datetime import date

import pytest

from pipeline.settings import ConfigError, cargar, inicio_fin_mes, validar_mes


def test_local_usa_rutas_relativas_resueltas_y_muestra():
    cfg = cargar("local")
    assert cfg["rutas"]["bronze"].endswith("/lake/bronze")
    assert cfg["rutas"]["bronze"].startswith("/")
    assert cfg["muestra"]["max_rows"] == 10000
    assert cfg["meses"] == ["2024-01"]


def test_dev_exige_lake_bucket(monkeypatch):
    monkeypatch.delenv("LAKE_BUCKET", raising=False)
    with pytest.raises(ConfigError, match="LAKE_BUCKET"):
        cargar("dev")


def test_dev_resuelve_placeholder_con_env(monkeypatch):
    monkeypatch.setenv("LAKE_BUCKET", "bigdata-lake-test-us-east-2")
    cfg = cargar("dev")
    assert cfg["rutas"]["silver"] == "s3://bigdata-lake-test-us-east-2/silver"
    assert cfg["muestra"]["max_rows"] is None


def test_entorno_desconocido():
    with pytest.raises(ConfigError):
        cargar("qa")


def test_inicio_fin_mes_incluye_cambio_de_anio():
    assert inicio_fin_mes("2024-12") == (date(2024, 12, 1), date(2025, 1, 1))
    assert inicio_fin_mes("2024-02") == (date(2024, 2, 1), date(2024, 3, 1))


@pytest.mark.parametrize("mes", ["2024-13", "24-01", "2024/01", ""])
def test_validar_mes_rechaza_formato_invalido(mes):
    with pytest.raises(ValueError):
        validar_mes(mes)
