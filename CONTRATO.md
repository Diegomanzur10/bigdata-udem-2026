# Contrato de interfaces del template (Fase 3)

Todos los componentes DEBEN usar estos nombres. No incluir IDs de cuenta, correos ni usuarios reales.

## Generales
- Región por defecto: `us-east-2`. Variable Terraform `aws_region`.
- Prefijo: variable `prefix` (default `bigdata`). Nombres: `${prefix}-<recurso>`.
- Python 3.11, PySpark 3.5.6. Glue `GlueVersion = "5.0"` (validado; 5.1 pendiente), WorkerType `G.1X`.
- Free plan AWS: **sin EMR**; EC2 solo tipos elegibles → VM Airflow `m7i-flex.large` (fallback `c7i-flex.large`).

## Bootstrap CloudFormation (`bootstrap/cloudformation/bootstrap.yaml`)
Parámetros: `GitHubOwner`, `GitHubRepo`, `GitHubOwnerId`, `GitHubRepoId` (para `sub` numérico), `VpcId`, `SubnetIds`, `AlertEmail`, `Prefix`, `BudgetUsd`, `ExistingGitHubOidcProviderArn` (opcional; si se pasa, no se crea el provider OIDC).
Crea: SageMaker Domain (VPC por defecto, AuthMode IAM, idle shutdown 60 min), UserProfile `estudiante`, Space CodeEditor `dev` (ml.t3.medium), rol de ejecución SageMaker `${Prefix}-sagemaker-exec`, OIDC provider GitHub + rol `${Prefix}-github-actions`, bucket de state `${Prefix}-tfstate-${AWS::AccountId}-${AWS::Region}` (versionado, cifrado, bloqueo público, `Retain`), Budget mensual `${Prefix}-monthly` con alertas 50/80/100 %, Lambda custom resource de limpieza del dominio al borrar.
IAM: política `${Prefix}-terraform-access` (+ PowerUserAccess) en los roles de SageMaker y GitHub, y política `${Prefix}-boundary` (permissions boundary).
- Los roles `${Prefix}-*` solo se pueden crear / modificar con `iam:PermissionsBoundary = arn:aws:iam::<cuenta>:policy/${Prefix}-boundary` (`CreateRole`, `PutRolePolicy`, `AttachRolePolicy`, `PutRolePermissionsBoundary`). Deny explícito: adjuntar `AdministratorAccess`/`IAMFullAccess`/`PowerUserAccess`, quitar el boundary, alterar `${Prefix}-boundary` y `${Prefix}-terraform-access`, y modificar los roles `github-actions` y `sagemaker-exec`.
- `iam:PassRole` sobre `${Prefix}-*` solo hacia `glue`, `ec2`, `scheduler` y `budgets` (`.amazonaws.com`); el último es para el rol de la acción de Budgets.
Outputs: `GitHubActionsRoleArn`, `TfStateBucket`, `PermissionsBoundaryArn`, `SageMakerExecutionRoleArn`, `DomainId`, `StudioConsoleUrl`.

## Terraform AWS (`infra/aws/`)
Backend S3 `use_lockfile = true`, bucket = output `TfStateBucket`, key `aws/terraform.tfstate`.
Módulos: `modules/lake`, `modules/glue`, `modules/airflow_vm`, `modules/guardrails`. Flags: `enable_glue` (default true), `enable_airflow` (default false). En `make deploy` y en CI no se usa `terraform.tfvars` (no se versiona): las variables llegan por entorno con `-var` / `TF_VAR_*`:
`ALERT_EMAIL` (`alert_email`, obligatoria; secret o variable del repo en CI, `.env` en local), `ENABLE_GLUE`, `ENABLE_AIRFLOW`, `SNOWFLAKE_IAM_USER_ARN` y `SNOWFLAKE_EXTERNAL_ID` (fase 2 de la integración; variables del repo en CI). Si la fase 2 no se pasa en CI, un apply revertiría la trust policy del rol de Snowflake a la fase 1.
- Variable `permissions_boundary_arn` (default: `arn:aws:iam::<cuenta>:policy/${prefix}-boundary`): la llevan TODOS los `aws_iam_role` que crea Terraform (`snowflake-s3`, `glue-exec`, `airflow-vm`, `airflow-stop-scheduler`, `budgets-action`).
- Lake bucket: `${prefix}-lake-${account_id}-${region}` con prefijos `bronze/ silver/ gold/ code/ dags/ logs/ tmp/`.
- Glue database: `${prefix}_lake`. Athena workgroup `${prefix}-wg` con límite de 1 GB escaneado por consulta.
- Glue jobs: `${prefix}-small` (2 workers, timeout 10), `${prefix}-medium` (4, 20), `${prefix}-large` (6, 30); `MaxConcurrentRuns = 3`; script `s3://<lake>/code/run_glue.py`, `--extra-py-files s3://<lake>/code/pipeline.zip` (zip con la carpeta `pipeline/` en su raíz); argumentos por defecto `--env dev` y `--lake-bucket <lake>`; Airflow agrega `--step`, `--env`, `--mes`. El engine siempre es `glue` (lo fija `run_glue.py`). Spark UI y logs continuos activados.
- Rol Glue `${prefix}-glue-exec`: solo su bucket (bronze/silver/gold/code/tmp/logs).
- VM Airflow: rol e instance profile `${prefix}-airflow-vm` (solo glue:StartJobRun/GetJobRun/BatchStopJobRun/GetJob sobre los 3 jobs, s3 read code/ dags/ logs/, secretsmanager GetSecretValue sobre `${prefix}/*`, SSM managed instance core), permissions boundary `${prefix}-boundary`, instancia con tag `Name=${prefix}-airflow` y `Project=${prefix}` (la sesión SSM exige este tag), SG `${prefix}-airflow-sg` sin ingress por defecto (variable `allowed_cidrs` para el fallback HTTP:8080), Elastic IP, EventBridge Scheduler apagado 23:00 America/Bogota.
- Guardrails: presupuesto `${prefix}-mensual`, política Deny `${prefix}-bloqueo-presupuesto` (glue:StartJobRun, ec2:StartInstances, ec2:RunInstances) que Budgets adjunta a `${prefix}-github-actions` y `${prefix}-airflow-vm` al 60 % de gasto real mediante el rol `${prefix}-budgets-action`; se revierte con `make desbloquear`.
- Secrets Manager: `${prefix}/airflow-admin` (JSON `username`/`password`, lo crea Terraform) y `${prefix}/snowflake` (JSON de conexión de Airflow `conn_type: snowflake`; Terraform solo crea el contenedor y el alumno guarda el valor).
- Outputs: `lake_bucket`, `glue_jobs`, `airflow_instance_id`, `airflow_public_ip`, `snowflake_s3_role_arn`.

## Terraform Snowflake (`infra/snowflake/`)
Provider `snowflakedb/snowflake` ~> 2.x, auth `SNOWFLAKE_JWT`. Backend S3 key `snowflake/terraform.tfstate`.
- Warehouse `${PREFIX}_WH` XSMALL, auto_suspend 60. Database `${PREFIX}`; schemas `BRONZE`, `SILVER`, `GOLD`.
- Resource monitor `${PREFIX}_RM` (60 créditos, notify 50/80, suspend_immediate 100) — creado y asignado a la cuenta (`ALTER ACCOUNT`, cubre a todos los warehouses) por `bootstrap/snowflake/01_admin.sql` con ACCOUNTADMIN; Terraform no lo asigna (el warehouse ignora `resource_monitor`). Snowflake rechaza asignarlo además al warehouse mientras esté a nivel de cuenta, así que 01_admin.sql se ejecuta una sola vez.
- Rol `BIGDATA_DEV`: USAGE en warehouse/database/schemas, CREATE TABLE/VIEW/STAGE/FILE FORMAT en schemas, USAGE+READ sobre el stage y SELECT sobre FUTURE TABLES / FUTURE VIEWS de BRONZE, SILVER y GOLD.
- Storage integration `${PREFIX}_S3_INT` en dos fases (rol IAM `${prefix}-snowflake-s3` creado en infra/aws con trust placeholder → actualizado con `STORAGE_AWS_IAM_USER_ARN` / `EXTERNAL_ID`). Stage `${PREFIX}.GOLD.LAKE_GOLD` → `s3://<lake>/gold/`.

## Pipeline (`src/pipeline/`)
- `run.py --step {bronze,silver,gold,all} --env {local,dev,prod} --engine {local,glue,snowpark_connect} [--mes YYYY-MM]`.
- `engine.py` crea la SparkSession según `--engine`; `io.py` lee/escribe según `config/<env>.yaml`.
- `bronze.py`, `silver.py`, `gold.py`: funciones puras `DataFrame -> DataFrame` + `main(spark, cfg, args)`. `quality.py` con chequeos.
- Datos: NYC TLC yellow trips Parquet (`https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_YYYY-MM.parquet`), taxi zones CSV, clima Open-Meteo (archive API) JSON.
- Gold: `gold/daily_zone_metrics/mes=YYYY-MM/*.parquet`. Columnas, en este orden: `fecha` DATE, `zona` VARCHAR, `viajes` LONG, `ingreso_total` DOUBLE, `propina_promedio` DOUBLE, `distancia_promedio` DOUBLE, `lluvia_mm` DOUBLE. La carpeta `mes=` solo es partición física (permite reprocesar un mes); todas las columnas, incluida `fecha`, van dentro de los Parquet porque Snowflake no lee columnas de partición.
- Snowflake: tabla `BIGDATA.GOLD.DAILY_ZONE_METRICS` (FECHA DATE, ZONA VARCHAR, VIAJES NUMBER(38,0), INGRESO_TOTAL/PROPINA_PROMEDIO/DISTANCIA_PROMEDIO/LLUVIA_MM FLOAT). `airflow/dags/sql/copy_gold.sql` hace `DELETE` del mes y `COPY INTO ... MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE ... FORCE = TRUE` desde `@BIGDATA.GOLD.LAKE_GOLD/daily_zone_metrics/mes=<mes>/` (reprocesos idempotentes).
- `run_glue.py`: entrypoint de Glue; fija `--engine glue` y delega en `pipeline.run.main`.

## Airflow (`airflow/`)
- Airflow 3.x, `docker-compose.yaml` con LocalExecutor + Postgres (sin Celery/Redis), `PYTHONPATH=/opt/airflow`.
- Despliegue a S3 (`make deploy` / `deploy.yml`): `build/pipeline.zip` → `s3://<lake>/code/pipeline.zip`; `src/pipeline/run_glue.py` → `code/run_glue.py`; `airflow/dags/` → `dags/`; `airflow/framework/` → `code/airflow/framework/`; `airflow/docker-compose.yaml` → `code/airflow/docker-compose.yaml`.
- La VM (`/usr/local/bin/airflow-refresh.sh`, en user_data, antes de cada arranque de `airflow.service` y por cron cada minuto para dags/ y framework/) copia esos objetos a `/opt/airflow/{dags,framework,docker-compose.yaml}` y arma `snowflake.env` (`AIRFLOW_CONN_SNOWFLAKE_DEFAULT`) desde el secreto `${prefix}/snowflake`. Los DAGs hacen `sys.path.insert` de la carpeta padre de `dags/` (donde vive `framework/`).
- `framework/tasks.py`: `glue_task(task_id, step, profile, env, mes)` → GlueJobOperator sobre `${prefix}-<profile>` (variable de Airflow `prefix`, que la VM fija con `AIRFLOW_VAR_PREFIX`); `snowflake_task(task_id, sql_file)` con la conexión `snowflake_default`.
- `framework/profiles.yaml`: small/medium/large.
- DAG ejemplo `dags/pipeline_taxi.py` con params `mes`, `env`, `engine`. Rama Glue: bronze → silver → gold → `cargar_gold` (COPY a Snowflake). Rama opcional `snowpark_connect`: escribe directo las tablas en Snowflake y no pasa por `cargar_gold`.

## GitHub Actions (`.github/workflows/`) y secrets
Secrets: `AWS_ROLE_ARN`, `TF_STATE_BUCKET`, `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY`, y `ALERT_EMAIL` (secret o variable; correo de Budgets).
Variables del repo (opcionales): `PREFIX`, `ENABLE_GLUE`, `ENABLE_AIRFLOW`, `SNOWFLAKE_IAM_USER_ARN`, `SNOWFLAKE_EXTERNAL_ID`.
Workflows: `ci.yml` (PR: ruff lint y formato, pytest, pytest de DAGs, terraform fmt/validate/plan), `deploy.yml` (main/dispatch: apply + empaquetar src → zip + sync dags/code/framework a S3), `airflow-on.yml`, `airflow-off.yml`, `permitir-ip.yml`, `quitar-ips.yml`, `debug-oidc.yml`. Acción `aws-actions/configure-aws-credentials@v6.3.0` (versiones verificadas contra GitHub en Fase 3).
- `permitir-ip.yml`: regla IPv4 `/32` en tcp/8080 del SG `${prefix}-airflow-sg`; descripción `etiqueta;fecha` (fecha ISO UTC; `;` y no `|`, que AWS no admite en descripciones); máximo 3 reglas (`MAX_REGLAS`), al superarlo se revoca la más antigua por fecha. `quitar-ips.yml` revoca una IP o todas.

## Makefile
`setup`, `doctor`, `estado`, `test`, `run-local`, `deploy`, `airflow-on`, `airflow-off`, `airflow-tunel`, `airflow-password`, `desbloquear`, `snowflake-ampliar-cuota`, `destroy` (+ `help`).
`.env` (no versionado) guarda `PREFIX`, `AWS_REGION`, `ALERT_EMAIL` y, opcionalmente, `ENABLE_AIRFLOW`, `ENABLE_GLUE`, `SNOWFLAKE_IAM_USER_ARN`, `SNOWFLAKE_EXTERNAL_ID`; `scripts/lib.sh` lo lee (el entorno tiene prioridad).
`make destroy`: vacía el lake, destruye infra/snowflake y luego infra/aws; opcionalmente (segunda confirmación) borra el stack de bootstrap y vacía/borra el bucket de state versionado.
