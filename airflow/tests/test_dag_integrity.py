"""Integridad del DAG pipeline_taxi: carga sin errores, número de tareas y orden."""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

import pytest

AIRFLOW_ROOT = Path(__file__).resolve().parents[1]
DAGS_DIR = AIRFLOW_ROOT / "dags"
DAG_ID = "pipeline_taxi"

# Airflow lee su configuración al importarse: fijar antes de cualquier import de airflow.
os.environ.setdefault("AIRFLOW_HOME", tempfile.mkdtemp(prefix="airflow_home_"))
os.environ.setdefault("AIRFLOW__CORE__LOAD_EXAMPLES", "False")
os.environ.setdefault("AIRFLOW__CORE__UNIT_TEST_MODE", "True")
if str(AIRFLOW_ROOT) not in sys.path:
    sys.path.insert(0, str(AIRFLOW_ROOT))


@pytest.fixture(scope="module")
def dag_bag():
    from airflow.dag_processing.dagbag import DagBag

    return DagBag(dag_folder=str(DAGS_DIR))


@pytest.fixture(scope="module")
def dag(dag_bag):
    # dags[...] evita consultar la base de datos de Airflow (no hay DB en el test).
    return dag_bag.dags[DAG_ID]


def _upstream_ids(task) -> set[str]:
    """Todos los ancestros de la tarea (transitivo)."""
    seen: set[str] = set()
    stack = list(task.upstream_task_ids)
    while stack:
        tid = stack.pop()
        if tid not in seen:
            seen.add(tid)
            stack.extend(task.dag.get_task(tid).upstream_task_ids)
    return seen


def test_no_import_errors(dag_bag):
    assert dag_bag.import_errors == {}, dag_bag.import_errors
    assert DAG_ID in dag_bag.dags


def test_dag_has_at_least_four_tasks(dag):
    assert len(dag.tasks) >= 4
    for tid in ("bronze", "silver", "gold", "cargar_gold"):
        dag.get_task(tid)  # lanza si no existe


def test_glue_chain_order(dag):
    assert dag.get_task("silver").upstream_task_ids == {"bronze"}
    assert dag.get_task("gold").upstream_task_ids == {"silver"}
    cargar = dag.get_task("cargar_gold")
    assert cargar.upstream_task_ids == {"gold"}
    assert {"bronze", "silver", "gold"} <= _upstream_ids(cargar)


def test_snowpark_branch_order(dag):
    assert dag.get_task("silver_snowpark").upstream_task_ids == {"bronze_snowpark"}
    assert dag.get_task("gold_snowpark").upstream_task_ids == {"silver_snowpark"}
    # La rama snowpark_connect escribe directo en Snowflake: no alimenta cargar_gold.
    assert dag.get_task("gold_snowpark").downstream_task_ids == set()
    assert "gold_snowpark" not in _upstream_ids(dag.get_task("cargar_gold"))


def test_branch_is_root_of_both_chains(dag):
    assert dag.get_task("bronze").upstream_task_ids == {"elegir_engine"}
    assert dag.get_task("bronze_snowpark").upstream_task_ids == {"elegir_engine"}


def test_dag_is_manual_with_params(dag):
    assert type(dag.timetable).__name__ == "NullTimetable"
    assert set(dag.params) >= {"mes", "env", "engine"}
    assert dag.params["mes"] == "2024-01"
    assert dag.params["env"] == "dev"
    assert dag.params["engine"] == "glue"


def test_glue_tasks_pasan_worker_type_y_numero_de_workers(dag):
    # StartJobRun falla con "Please set both Worker Type and Number of Workers" si falta uno.
    for task_id in ("bronze", "silver", "gold"):
        kwargs = dag.get_task(task_id).run_job_kwargs
        assert kwargs["WorkerType"] == "G.1X"
        assert kwargs["NumberOfWorkers"] >= 2
