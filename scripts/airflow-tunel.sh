#!/usr/bin/env bash
# Abre un port forwarding SSM: localhost:8080 -> Airflow:8080. Ctrl+C para cerrar.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

requerir aws session-manager-plugin
ID="$(find_airflow_instance_id)"
[[ -n "$ID" ]] || error "No existe la instancia ${PREFIX}-airflow."

ESTADO="$(instance_state "$ID")"
[[ "$ESTADO" == "running" ]] || error "La instancia está '$ESTADO'. Ejecuta 'make airflow-on' primero."

STUDIO="$(studio_console_url)"
msg "Túnel SSM hacia $ID (8080 -> localhost:8080). Ctrl+C para cerrar."
echo "URL local: http://localhost:8080"
if [[ -n "$STUDIO" ]]; then
  echo "URL proxy de Studio (a validar): ${STUDIO%/}/codeeditor/default/proxy/8080/"
else
  aviso "No se encontró StudioConsoleUrl en el stack ${BOOTSTRAP_STACK:-${PREFIX}-bootstrap}."
fi

aws ssm start-session \
  --target "$ID" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}'
