"""CLI del pipeline.

    python -m pipeline.run --step {bronze,silver,gold,all} --env {local,dev,prod} \
        --engine {local,glue,snowpark_connect} [--mes YYYY-MM] [--lake-bucket NOMBRE]

Sin --mes se procesan los meses de config/<env>.yaml. Requiere PYTHONPATH=src
(o ejecutar desde el paquete instalado).
"""

from __future__ import annotations

import argparse
import logging
import os
import sys

from pipeline import bronze, engine, gold, silver
from pipeline.settings import ENTORNOS, cargar, validar_mes

PASOS = {"bronze": bronze, "silver": silver, "gold": gold}
log = logging.getLogger("pipeline")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Pipeline bronze/silver/gold")
    p.add_argument("--step", required=True, choices=[*PASOS, "all"])
    p.add_argument("--env", required=True, choices=ENTORNOS)
    p.add_argument("--engine", required=True, choices=engine.MOTORES)
    p.add_argument("--mes", type=validar_mes, default=None, help="YYYY-MM")
    p.add_argument(
        "--lake-bucket",
        default=None,
        help="nombre del bucket del lake (equivale a LAKE_BUCKET; solo env dev/prod)",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    if args.lake_bucket:
        os.environ["LAKE_BUCKET"] = args.lake_bucket

    cfg = cargar(args.env)
    meses = [args.mes] if args.mes else cfg["meses"]
    pasos = list(PASOS) if args.step == "all" else [args.step]

    spark = None
    if args.engine == "snowpark_connect" or any(p != "bronze" for p in pasos):
        spark = engine.get_spark(args.engine)

    for mes in meses:
        for paso in pasos:
            log.info("Paso=%s env=%s engine=%s mes=%s", paso, args.env, args.engine, mes)
            ns = argparse.Namespace(step=paso, env=args.env, engine=args.engine, mes=mes)
            PASOS[paso].main(spark, cfg, ns)
    return 0


if __name__ == "__main__":
    sys.exit(main())
