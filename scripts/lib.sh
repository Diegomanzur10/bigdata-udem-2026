#!/usr/bin/env bash
# Funciones y variables comunes para los scripts de scripts/ (Makefile y workflows).
# Compatible con bash 3.2 (macOS): sin mapfile, sin ${var,,}, sin arrays vacíos con set -u.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Configuración local (.env, no versionado). Lo que ya esté en el entorno tiene prioridad.
if [[ -f "$ROOT_DIR/.env" ]]; then
  while IFS='=' read -r _k _v; do
    if [[ "$_k" =~ ^[A-Z][A-Z0-9_]*$ && -z "${!_k:-}" ]]; then
      export "$_k=$_v"
    fi
  done < "$ROOT_DIR/.env"
  unset _k _v
fi

PREFIX="${PREFIX:-bigdata}"
AWS_REGION="${AWS_REGION:-us-east-2}"
export PREFIX AWS_REGION
export AWS_DEFAULT_REGION="$AWS_REGION"
export TF_VAR_prefix="$PREFIX"
export TF_VAR_aws_region="$AWS_REGION"

# Entorno virtual local (creado por 'make setup') tiene prioridad en el PATH.
if [[ -d "$ROOT_DIR/.venv/bin" ]]; then
  export PATH="$ROOT_DIR/.venv/bin:$PATH"
fi

msg() { echo "==> $*"; }
aviso() { echo "AVISO: $*" >&2; }
error() { echo "ERROR: $*" >&2; exit 1; }

requerir() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || error "Falta la herramienta '$cmd'. Instálala y vuelve a intentar (make setup)."
  done
}

confirmar() {
  # Uso: confirmar "<texto>" "<palabra exacta>"
  local texto="$1" palabra="$2" respuesta
  if [[ ! -t 0 ]]; then
    error "Se requiere confirmación interactiva. Ejecuta el comando desde una terminal."
  fi
  echo "$texto"
  read -r -p "Escribe '$palabra' para continuar: " respuesta
  [[ "$respuesta" == "$palabra" ]] || error "Cancelado: no se escribió '$palabra'."
}

set_env_var() {
  # Actualiza o agrega CLAVE=valor en .env (no versionado) sin tocar el resto.
  local clave="$1" valor="$2" archivo="$ROOT_DIR/.env" tmp
  touch "$archivo"
  tmp="$(mktemp)"
  grep -v "^${clave}=" "$archivo" > "$tmp" || true
  echo "${clave}=${valor}" >> "$tmp"
  mv "$tmp" "$archivo"
}

account_id() {
  aws sts get-caller-identity --query Account --output text
}

lake_bucket() {
  echo "${PREFIX}-lake-$(account_id)-${AWS_REGION}"
}

tfstate_bucket() {
  echo "${TF_STATE_BUCKET:-${PREFIX}-tfstate-$(account_id)-${AWS_REGION}}"
}

find_airflow_instance_id() {
  # Devuelve el ID de la instancia Airflow (no terminada) o cadena vacía.
  local ids
  ids="$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${PREFIX}-airflow" \
              "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || true)"
  ids="$(echo "$ids" | tr '\t' '\n' | grep -v '^None$' | grep -v '^$' | head -1 || true)"
  echo "$ids"
}

instance_state() {
  aws ec2 describe-instances --instance-ids "$1" \
    --query 'Reservations[0].Instances[0].State.Name' --output text
}

instance_public_ip() {
  local ip
  ip="$(aws ec2 describe-instances --instance-ids "$1" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || true)"
  if [[ -z "$ip" || "$ip" == "None" ]]; then
    echo ""
  else
    echo "$ip"
  fi
}

# Variables de Terraform de infra/aws que vienen del entorno (.env en local; variables y secrets
# de GitHub en CI). Se pasan con -var porque ganan sobre terraform.tfvars: así 'make deploy' y
# deploy.yml aplican lo mismo. Deja el resultado en el arreglo TF_AWS_VARS.
#   ALERT_EMAIL                              -> alert_email (obligatoria)
#   ENABLE_AIRFLOW / ENABLE_GLUE             -> enable_airflow / enable_glue (true|false)
#   SNOWFLAKE_IAM_USER_ARN / SNOWFLAKE_EXTERNAL_ID -> fase 2 de la storage integration
armar_vars_aws() {
  TF_AWS_VARS=()
  if [[ -n "${ALERT_EMAIL:-}" ]]; then TF_AWS_VARS+=(-var "alert_email=${ALERT_EMAIL}"); fi
  if [[ -n "${ENABLE_AIRFLOW:-}" ]]; then TF_AWS_VARS+=(-var "enable_airflow=${ENABLE_AIRFLOW}"); fi
  if [[ -n "${ENABLE_GLUE:-}" ]]; then TF_AWS_VARS+=(-var "enable_glue=${ENABLE_GLUE}"); fi
  if [[ -n "${SNOWFLAKE_IAM_USER_ARN:-}" ]]; then
    TF_AWS_VARS+=(-var "snowflake_iam_user_arn=${SNOWFLAKE_IAM_USER_ARN}")
  fi
  if [[ -n "${SNOWFLAKE_EXTERNAL_ID:-}" ]]; then
    TF_AWS_VARS+=(-var "snowflake_external_id=${SNOWFLAKE_EXTERNAL_ID}")
  fi
}

studio_console_url() {
  # Salida StudioConsoleUrl del stack de bootstrap (nombre por defecto ${PREFIX}-bootstrap).
  local stack="${BOOTSTRAP_STACK:-${PREFIX}-bootstrap}"
  aws cloudformation describe-stacks --stack-name "$stack" \
    --query "Stacks[0].Outputs[?OutputKey=='StudioConsoleUrl'].OutputValue" --output text 2>/dev/null || true
}
