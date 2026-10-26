#!/usr/bin/env bash
# Verifica herramientas, valida la región de Snowflake y alinea AWS_REGION (.env).
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

msg "Verificando herramientas"
requerir python3 aws terraform snow jq zip

python3 -c 'import sys; sys.exit(0 if sys.version_info[:2] >= (3, 11) else 1)' \
  || error "Se requiere Python 3.11 o superior (python3 --version)."

if ! java -version 2>&1 | head -1 | grep -q '"17'; then
  aviso "Se recomienda Java 17 para PySpark 3.5 (java -version)."
fi

if ! command -v session-manager-plugin >/dev/null 2>&1; then
  aviso "session-manager-plugin no está instalado; 'make airflow-tunel' no funcionará."
fi

msg "Entorno virtual y dependencias de desarrollo"
if [[ ! -d "$ROOT_DIR/.venv" ]]; then
  python3 -m venv "$ROOT_DIR/.venv"
fi
if [[ -f "$ROOT_DIR/requirements-dev.txt" ]]; then
  "$ROOT_DIR/.venv/bin/python" -m pip install --quiet --upgrade pip
  "$ROOT_DIR/.venv/bin/python" -m pip install --quiet -r "$ROOT_DIR/requirements-dev.txt"
else
  aviso "No existe requirements-dev.txt; se omite la instalación de dependencias."
fi

msg "Validando región de Snowflake (snow sql)"
SNOW_OUT="$(snow sql -q "select current_region()" 2>&1)" \
  || error "No se pudo consultar Snowflake. Revisa la conexión con 'snow connection test'.\n$SNOW_OUT"

SNOW_REGION="$(grep -oE '[A-Z]+_[A-Z0-9_]+' <<< "$SNOW_OUT" | grep -E '^(AWS|AZURE|GCP)_' | head -1 || true)"
[[ -n "$SNOW_REGION" ]] || error "No se pudo leer la región de Snowflake. Salida:\n$SNOW_OUT"
if [[ "$SNOW_REGION" != AWS_* ]]; then
  error "La cuenta de Snowflake está en '$SNOW_REGION'. Debe estar en AWS_* para usar el bucket S3 de este template."
fi

REGION_DESDE_SNOW="$(sed -e 's/^AWS_//' -e 's/_/-/g' <<< "$SNOW_REGION" | tr "[:upper:]" "[:lower:]")"
msg "Región de Snowflake: $SNOW_REGION -> $REGION_DESDE_SNOW"

if [[ "$REGION_DESDE_SNOW" != "$AWS_REGION" ]]; then
  aviso "AWS_REGION ($AWS_REGION) difiere de la región de Snowflake; se alinea a $REGION_DESDE_SNOW."
  AWS_REGION="$REGION_DESDE_SNOW"
fi

set_env_var PREFIX "$PREFIX"
set_env_var AWS_REGION "$AWS_REGION"

# Correo de alertas de Budgets (variable alert_email de Terraform). Se guarda en .env (no versionado).
if [[ -z "${ALERT_EMAIL:-}" && -t 0 ]]; then
  read -r -p "Correo para las alertas de presupuesto (ALERT_EMAIL): " ALERT_EMAIL
fi
if [[ -n "${ALERT_EMAIL:-}" ]]; then
  [[ "$ALERT_EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] || error "ALERT_EMAIL no es un correo válido: $ALERT_EMAIL"
  set_env_var ALERT_EMAIL "$ALERT_EMAIL"
else
  aviso "ALERT_EMAIL sin definir: 'make deploy' lo exige (agrégalo a .env o a infra/aws/terraform.tfvars)."
fi
msg "Configuración guardada en .env (PREFIX=$PREFIX, AWS_REGION=$AWS_REGION)"
msg "Setup completado. Siguiente paso: make doctor"
