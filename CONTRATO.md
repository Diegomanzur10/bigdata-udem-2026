# Contrato de interfaces del template (Fase 3)

Todos los componentes DEBEN usar estos nombres. No incluir IDs de cuenta, correos ni usuarios reales.

## Generales
- Región por defecto: `us-east-2`. Variable Terraform `aws_region`.
- Prefijo: variable `prefix` (default `bigdata`). Nombres: `${prefix}-<recurso>`.
- Python 3.11, PySpark 3.5.6. Glue `GlueVersion = "5.0"` (validado; 5.1 pendiente), WorkerType `G.1X`.
- Free plan AWS: **sin EMR**; EC2 solo tipos elegibles → VM Airflow `m7i-flex.large` (fallback `c7i-flex.large`).

## Bootstrap CloudFormation (`bootstrap/cloudformation/bootstrap.yaml`)
Parámetros: `GitHubOwner`, `GitHubRepo`, `GitHubOwnerId`, `GitHubRepoId` (para `sub` numérico), `AlertEmail`, `Prefix`.
Crea: SageMaker Domain (VPC por defecto, AuthMode IAM, idle shutdown 60 min), UserProfile `estudiante`, Space CodeEditor `dev` (ml.t3.medium), rol de ejecución SageMaker, OIDC provider GitHub + rol `${Prefix}-github-actions`, bucket de state `${Prefix}-tfstate-${AWS::AccountId}-${AWS::Region}` (versionado, cifrado, bloqueo público), Budget mensual con alertas 50/80/100 %, Lambda custom resource de limpieza del dominio al borrar.
Outputs: `GitHubActionsRoleArn`, `TfStateBucket`, `SageMakerExecutionRoleArn`, `DomainId`, `StudioConsoleUrl`.

## Terraform AWS (`infra/aws/`)
Backend S3 `use_lockfile = true`, bucket = output `TfStateBucket`, key `aws/terraform.tfstate`.
Módulos: `modules/lake`, `modules/glue`, `modules/airflow_vm`, `modules/guardrails`. Flags en `terraform.tfvars`: `enable_glue`, `enable_airflow`.
- Lake bucket: `${prefix}-lake-${account_id}-${region}` con prefijos `bronze/ silver/ gold/ code/ dags/ logs/ tmp/`.
- Glue database: `${prefix}_lake`. Athena workgroup `${prefix}-wg` con límite de 1 GB escaneado por consulta.
- Glue jobs: `${prefix}-small` (2 workers, timeout 10), `${prefix}-medium` (4, 20), `${prefix}-large` (6, 30); `MaxConcurrentRuns` = 3; script `s3://<lake>/code/run_glue.py`, `--extra-py-files s3://<lake>/code/pipeline.zip`; Spark UI y logs continuos activados.
- Rol Glue `${prefix}-glue-exec`: solo su bucket (bronze/silver/gold/code/tmp/logs).
- VM Airflow: rol `${prefix}-airflow-vm` (solo glue:StartJobRun/GetJobRun/BatchStopJobRun sobre los 3 jobs, s3 read code/ dags/ logs/, secretsmanager sobre `${prefix}/*`, SSM managed instance core), permissions boundary, SG sin ingress por defecto (variable `allowed_cidrs` para el fallback HTTP:8080), Elastic IP, EventBridge Scheduler apagado 23:00 America/Bogota.
- Secrets: `${prefix}/airflow-admin`, `${prefix}/snowflake`.
- Outputs: `lake_bucket`, `glue_jobs`, `airflow_instance_id`, `airflow_public_ip`, `snowflake_s3_role_arn`.

## Terraform Snowflake (`infra/snowflake/`)
Provider `snowflakedb/snowflake` ~> 2.x, auth `SNOWFLAKE_JWT`. Backend S3 key `snowflake/terraform.tfstate`.
- Warehouse `${PREFIX}_WH` XSMALL, auto_suspend 60. Database `${PREFIX}`; schemas `BRONZE`, `SILVER`, `GOLD`.
- Resource monitor `${PREFIX}_RM` (60 créditos, notify 50/80, suspend_immediate 100) — creado por `bootstrap/snowflake/01_admin.sql` con ACCOUNTADMIN.
- Storage integration `${PREFIX}_S3_INT` en dos fases (rol IAM `${prefix}-snowflake-s3` creado en infra/aws con trust placeholder → actualizado con `STORAGE_AWS_IAM_USER_ARN` / `EXTERNAL_ID`). Stage `${PREFIX}.GOLD.LAKE_GOLD` → `s3://<lake>/gold/`.

## Pipeline (`src/pipeline/`)
- `run.py --step {bronze,silver,gold,all} --env {local,dev,prod} --engine {local,glue,snowpark_connect} [--mes YYYY-MM]`.
- `engine.py` crea la SparkSession según `--engine`; `io.py` lee/escribe según `config/<env>.yaml`.
- `bronze.py`, `silver.py`, `gold.py`: funciones puras `DataFrame -> DataFrame` + `main(spark, cfg, args)`. `quality.py` con chequeos.
- Datos: NYC TLC yellow trips Parquet (`https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_YYYY-MM.parquet`), taxi zones CSV, clima Open-Meteo (archive API) JSON.
- Gold: `gold/daily_zone_metrics` (fecha, zona, viajes, ingreso_total, propina_promedio, distancia_promedio, lluvia_mm).
- `run_glue.py`: entrypoint de Glue que invoca `pipeline.run`.

## Airflow (`airflow/`)
- Airflow 3.x, `docker-compose.yaml` con LocalExecutor + Postgres (sin Celery/Redis), DAGs sincronizados desde `s3://<lake>/dags/`.
- `framework/tasks.py`: `glue_task(task_id, step, profile, env, mes)` → GlueJobOperator sobre `${prefix}-<profile>`; `snowflake_task(task_id, sql_file)`.
- `framework/profiles.yaml`: small/medium/large.
- DAG ejemplo `dags/pipeline_taxi.py` con params `mes`, `env`, `engine`.

## GitHub Actions (`.github/workflows/`) y secrets
Secrets: `AWS_ROLE_ARN`, `TF_STATE_BUCKET`, `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY`.
Workflows: `ci.yml` (PR: ruff, pytest, terraform fmt/validate/plan), `deploy.yml` (main/dispatch: apply + empaquetar src → zip + sync dags/code a S3), `airflow-on.yml`, `airflow-off.yml`, `permitir-ip.yml`, `quitar-ips.yml`, `debug-oidc.yml`. Acción `aws-actions/configure-aws-credentials@v4` o superior.

## Makefile
`setup`, `doctor`, `estado`, `test`, `run-local`, `deploy`, `airflow-on`, `airflow-off`, `airflow-tunel`, `airflow-password`, `desbloquear`, `snowflake-ampliar-cuota`, `destroy`.
