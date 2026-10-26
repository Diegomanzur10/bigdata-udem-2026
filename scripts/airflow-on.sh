#!/usr/bin/env bash
# Enciende la instancia de Airflow (tag Name=${PREFIX}-airflow) e imprime la URL.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

requerir aws
ID="$(find_airflow_instance_id)"
[[ -n "$ID" ]] || error "No existe la instancia ${PREFIX}-airflow (¿enable_airflow = true y terraform apply?)."

ESTADO="$(instance_state "$ID")"
if [[ "$ESTADO" == "running" ]]; then
  msg "La instancia $ID ya está encendida."
else
  msg "Encendiendo instancia $ID (estado actual: $ESTADO)"
  aws ec2 start-instances --instance-ids "$ID" >/dev/null
  aws ec2 wait instance-running --instance-ids "$ID"
fi

IP="$(instance_public_ip "$ID")"
if [[ -n "$IP" ]]; then
  msg "Airflow encendido. URL: http://${IP}:8080"
else
  aviso "La instancia no tiene IP pública; revisa la Elastic IP."
fi
echo "Acceso: 'make airflow-tunel' (recomendado) o workflow 'permitir-ip' para tu IP."
