#!/usr/bin/env bash
# Ejecuta el pipeline en local. Variables: STEP (bronze|silver|gold|all), MES (YYYY-MM), ENGINE (local).
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STEP="${STEP:-all}"
ENGINE="${ENGINE:-local}"
requerir python3

case "$STEP" in
  bronze|silver|gold|all) ;;
  *) error "STEP inválido: '$STEP' (usa bronze, silver, gold o all)." ;;
esac

ARGS="--step $STEP --env local --engine $ENGINE"
if [[ -n "${MES:-}" ]]; then
  [[ "$MES" =~ ^[0-9]{4}-[0-9]{2}$ ]] || error "MES debe tener formato YYYY-MM (recibido: $MES)."
  ARGS="$ARGS --mes $MES"
fi

msg "Pipeline local: $ARGS"
cd "$ROOT_DIR/src" || exit 1
# shellcheck disable=SC2086
exec python3 -m pipeline.run $ARGS
