"""DAG pipeline_taxi: bronze -> silver -> gold (Glue) -> carga a Snowflake.

Rama opcional: con params.engine = "snowpark_connect" se ejecutan los mismos steps con
snowpark_connect_task (comparación de engines). Esa rama escribe directamente las tablas
BIGDATA.<CAPA>.* en Snowflake, así que no necesita cargar_gold (solo cuelga de la rama Glue).
Disparo manual: los params mes / env / engine se eligen al lanzar el DAG.
"""

from __future__ import annotations

import sys
from datetime import datetime
from pathlib import Path

from airflow.models.param import Param
from airflow.providers.standard.operators.python import BranchPythonOperator
from airflow.sdk import DAG

# airflow/ es la raíz del paquete `framework` (en la VM, debe estar desplegada junto a dags/).
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from framework.tasks import (
    glue_task,
    snowflake_task,
    snowpark_connect_task,
)


def _elegir_engine(**context) -> str:
    """Devuelve el task_id de la rama a ejecutar según params.engine."""
    engine = context["params"]["engine"]
    return "bronze_snowpark" if engine == "snowpark_connect" else "bronze"


with DAG(
    dag_id="pipeline_taxi",
    schedule=None,
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["bigdata", "taxi"],
    params={
        "mes": Param(
            "2024-01",
            type="string",
            pattern=r"^\d{4}-\d{2}$",
            description="Mes YYYY-MM",
        ),
        "env": Param("dev", type="string", enum=["dev", "prod"]),
        "engine": Param("glue", type="string", enum=["glue", "snowpark_connect"]),
    },
) as dag:
    elegir_engine = BranchPythonOperator(task_id="elegir_engine", python_callable=_elegir_engine)

    # Rama principal: Glue.
    bronze = glue_task("bronze", step="bronze", profile="small")
    silver = glue_task("silver", step="silver", profile="medium")
    gold = glue_task("gold", step="gold", profile="medium")

    # Rama opcional: Snowpark Connect (comparación).
    bronze_snowpark = snowpark_connect_task("bronze_snowpark", step="bronze")
    silver_snowpark = snowpark_connect_task("silver_snowpark", step="silver")
    gold_snowpark = snowpark_connect_task("gold_snowpark", step="gold")

    # Solo la rama Glue deja Parquet en S3 que cargar; si se elige snowpark_connect, queda skipped.
    cargar_gold = snowflake_task("cargar_gold", sql_file="sql/copy_gold.sql")

    elegir_engine >> bronze >> silver >> gold >> cargar_gold
    elegir_engine >> bronze_snowpark >> silver_snowpark >> gold_snowpark
