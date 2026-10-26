#!/usr/bin/env bash
# Despliegue local equivalente a .github/workflows/deploy.yml:
# terraform apply de infra/aws y sincronización de código y DAGs a S3.
#
# Variables (en .env o en el entorno): ALERT_EMAIL (obligatoria si no está en
# infra/aws/terraform.tfvars), ENABLE_AIRFLOW, ENABLE_GLUE, SNOWFLAKE_IAM_USER_ARN y
# SNOWFLAKE_EXTERNAL_ID (fase 2 de la integración con Snowflake). Ver armar_vars_aws en lib.sh.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

requerir aws terraform zip

BUCKET_ESTADO="$(tfstate_bucket)"
LAKE="$(lake_bucket)"
msg "Bucket de estado: $BUCKET_ESTADO"
msg "Bucket del lake: $LAKE"

if [[ -z "${ALERT_EMAIL:-}" ]] && ! grep -qs '^[[:space:]]*alert_email[[:space:]]*=' "$ROOT_DIR/infra/aws/terraform.tfvars"; then
  error "Falta el correo de alertas. Define ALERT_EMAIL en .env (make setup lo pide) o alert_email en infra/aws/terraform.tfvars."
fi
armar_vars_aws

PLAN_FILE="$(mktemp -t tfplan.XXXXXX)"
trap 'rm -f "$PLAN_FILE"' EXIT

msg "Terraform init (infra/aws)"
cd "$ROOT_DIR/infra/aws" || exit 1
terraform init -input=false \
  -backend-config="bucket=$BUCKET_ESTADO" \
  -backend-config="key=aws/terraform.tfstate" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="use_lockfile=true"

msg "Terraform plan (infra/aws)"
terraform plan -input=false -lock-timeout=5m -out="$PLAN_FILE" ${TF_AWS_VARS[@]+"${TF_AWS_VARS[@]}"}

msg "Terraform apply (revisa el plan anterior)"
terraform apply -input=false -lock-timeout=5m "$PLAN_FILE"

msg "Empaquetando src/pipeline"
cd "$ROOT_DIR" || exit 1
mkdir -p build
rm -f build/pipeline.zip
(cd src && zip -r -q ../build/pipeline.zip pipeline -x '*/__pycache__/*' '*.pyc')

msg "Subiendo código, DAGs y framework a s3://$LAKE/"
aws s3 cp build/pipeline.zip "s3://$LAKE/code/pipeline.zip"
aws s3 cp src/pipeline/run_glue.py "s3://$LAKE/code/run_glue.py"
aws s3 sync airflow/dags "s3://$LAKE/dags/" --delete --exclude '*__pycache__*'
aws s3 sync airflow/framework "s3://$LAKE/code/airflow/framework/" --delete --exclude '*__pycache__*'
aws s3 cp airflow/docker-compose.yaml "s3://$LAKE/code/airflow/docker-compose.yaml"

msg "Deploy completado"
echo "Si la VM de Airflow ya estaba encendida, se actualiza sola en ~1 min (DAGs y framework)."
echo "El docker-compose.yaml se aplica al próximo arranque de la VM (make airflow-off && make airflow-on)."
