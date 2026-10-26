# Targets del template (ver CONTRATO.md). Cada target delega en scripts/*.sh.
SHELL := /bin/bash
.DEFAULT_GOAL := help

# Configuración local generada por 'make setup' (.env no versionado).
-include .env
PREFIX ?= bigdata
AWS_REGION ?= us-east-2
export PREFIX AWS_REGION
export PATH := $(CURDIR)/.venv/bin:$(PATH)

.PHONY: help setup doctor estado test run-local deploy airflow-on airflow-off \
	airflow-tunel airflow-password desbloquear snowflake-ampliar-cuota destroy

help: ## Muestra los targets disponibles
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-24s %s\n", $$1, $$2}'

setup: ## Verifica herramientas, valida la región de Snowflake y alinea AWS_REGION
	bash scripts/setup.sh

doctor: ## Diagnóstico: versiones, AWS, Snowflake, Terraform y estado OIDC
	bash scripts/doctor.sh

estado: ## Airflow (on/off + URL), últimos job runs de Glue, warehouse y costos
	bash scripts/estado.sh

test: ## Ruff y pytest
	bash scripts/test.sh

run-local: ## Ejecuta el pipeline en local (STEP=all MES=YYYY-MM)
	STEP=$(STEP) MES=$(MES) bash scripts/run-local.sh

deploy: ## terraform apply de infra/aws y sincronización de código, DAGs y framework a S3
	bash scripts/deploy.sh

airflow-on: ## Enciende la instancia de Airflow e imprime la URL
	bash scripts/airflow-on.sh

airflow-off: ## Apaga la instancia de Airflow
	bash scripts/airflow-off.sh

airflow-tunel: ## Túnel SSM localhost:8080 -> Airflow (y URL del proxy de Studio)
	bash scripts/airflow-tunel.sh

airflow-password: ## Muestra usuario y contraseña de Airflow (Secrets Manager)
	bash scripts/airflow-password.sh

desbloquear: ## Revierte las acciones de Budgets (quita la política Deny), con confirmación
	bash scripts/desbloquear.sh

snowflake-ampliar-cuota: ## Amplía la cuota de créditos del resource monitor (CUOTA=N)
	CUOTA=$(CUOTA) bash scripts/snowflake-ampliar-cuota.sh

destroy: ## Vacía el lake y destruye Snowflake y AWS; opcional: bootstrap y state (confirmación escrita)
	bash scripts/destroy.sh
