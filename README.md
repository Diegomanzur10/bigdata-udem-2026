# bigdata-udem-2026

Template del curso de Big Data de la UdeM: un pipeline de datos de punta a punta (SQL, PySpark, AWS y Snowflake) que cada estudiante despliega en su propia cuenta con Terraform y GitHub Actions.

El pipeline procesa los viajes de taxi amarillo de NYC (NYC TLC), las zonas de taxi y el clima diario (Open-Meteo) en tres capas, y publica una tabla de métricas diarias por zona en Snowflake.

## Arquitectura

```
                       NYC TLC (Parquet)   taxi zones (CSV)   Open-Meteo (JSON)
                                  \              |               /
                                   v             v              v
  GitHub (tu fork)           +-----------------------------------------+
  push a main  -----------> |  AWS Glue 5.0 (PySpark 3.5)  jobs        |
  GitHub Actions (OIDC)     |  bigdata-small | -medium | -large         |
        |                   +--------------------+--------------------+
        | terraform apply                        | lee / escribe
        v                                        v
  +---------------+        +----------------------------------------------+
  | infra/aws     |        |  S3  bigdata-lake-<cuenta>-us-east-2         |
  | (Terraform)   |------->|  bronze/  silver/  gold/  code/  dags/       |
  +---------------+        +----------------+-----------------------------+
        |                                   |                    ^
        | crea                              | COPY INTO          | sync dags/framework
        v                                   v                    |
  +-----------------+              +------------------+   +-------------------------+
  | Athena (1 GB    |              | Snowflake        |   | VM Airflow (EC2)        |
  | por consulta)   |              | BIGDATA.GOLD     |<--| Docker: Airflow 3 +     |
  +-----------------+              | DAILY_ZONE_      |   | Postgres, apagado 23:00 |
                                   | METRICS          |   +-------------------------+
  Code Editor (SageMaker) ---->    +------------------+     acceso: túnel SSM o IP
  tu entorno de trabajo            infra/snowflake          permitida (workflow)

  Guardrails: Budget mensual + política Deny al 60 % + resource monitor de Snowflake
```

- **Bootstrap** (`bootstrap/`): una plantilla de CloudFormation que crea tu entorno de trabajo (SageMaker Code Editor), el acceso de GitHub Actions a AWS por OIDC (sin claves), el bucket de state de Terraform y un presupuesto con alertas; más un script SQL para Snowflake.
- **Infraestructura** (`infra/aws`, `infra/snowflake`): Terraform. AWS: lake S3, catálogo Glue y Athena, jobs Glue, VM de Airflow opcional y guardrails de costo. Snowflake: warehouse XS, base `BIGDATA` (BRONZE, SILVER, GOLD), rol `BIGDATA_DEV` y stage externo sobre `gold/`.
- **Pipeline** (`src/pipeline`): bronze (descarga sin transformar) -> silver (limpieza y enriquecimiento) -> gold (métricas diarias por zona). Corre en local, en Glue o con Snowpark Connect.
- **Orquestación** (`airflow/`): DAG `pipeline_taxi` (Glue -> `COPY INTO` a Snowflake).
- **Automatización**: `Makefile` + `scripts/` + `.github/workflows/`.

Detalle de nombres e interfaces: [CONTRATO.md](CONTRATO.md). Más documentos: [docs/bootstrap.md](docs/bootstrap.md), [airflow/README.md](airflow/README.md), [infra/snowflake/README.md](infra/snowflake/README.md).

## Quickstart del estudiante

Haz los pasos en este orden.

1. **Snowflake: cuenta trial en AWS, región `us-east-2`.** Crea la cuenta de prueba en snowflake.com eligiendo la nube **AWS** y la región **US East (Ohio)**. Si queda en Azure/GCP o en otra región de AWS, `make setup` te lo avisará y tendrás que crear otra cuenta.
2. **Cuenta AWS.** Crea tu cuenta de AWS (plan gratuito) y trabaja siempre en `us-east-2`. Entra con un usuario con permisos de administrador solo para lanzar el bootstrap.
3. **Fork y Actions.** Haz fork de este repositorio en tu GitHub. En el fork, pestaña **Actions**, habilita los workflows ("I understand my workflows, go ahead and enable them").
4. **Launch Stack (bootstrap AWS).** Sigue [docs/bootstrap.md](docs/bootstrap.md): obtén los IDs numéricos de tu usuario y repo, elige la VPC por defecto y lanza el stack `bigdata-bootstrap` con CloudFormation. Espera `CREATE_COMPLETE` y copia los outputs `GitHubActionsRoleArn` y `TfStateBucket`.
5. **Code Editor.** Abre `StudioConsoleUrl` -> perfil `estudiante` -> Space `dev` -> **Code Editor**.
6. **Clona tu fork** en la terminal del Code Editor:
   ```bash
   git clone https://github.com/<TU_USUARIO>/<TU_FORK>.git && cd <TU_FORK>
   ```
7. **`make setup`.** Verifica herramientas (Python 3.11, Java 17, AWS CLI, Terraform, Snowflake CLI `snow`, jq, zip), crea `.venv`, valida que Snowflake esté en AWS, alinea `AWS_REGION` y, si todavía no existe, crea en S3 la configuración de Terraform (te pide el correo de alertas). Antes configura `snow` (`~/.snowflake/config.toml`) y comprueba con `make doctor`.
8. **Secrets del fork** (Settings > Secrets and variables > Actions):

   | Nombre | Tipo | Valor |
   |---|---|---|
   | `AWS_ROLE_ARN` | secret | output `GitHubActionsRoleArn` del bootstrap |
   | `TF_STATE_BUCKET` | secret | output `TfStateBucket` del bootstrap |
   | `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY` | secrets | reservados para workflows de Snowflake; los workflows actuales no los usan |

   La configuración de Terraform (correo de alertas, Airflow, Glue y la fase 2 de Snowflake) no va en secrets ni variables: está en S3 ([ver abajo](#configuración-por-estudiante)).

9. **`make deploy`.** Aplica `infra/aws` (lake, Glue, Athena, guardrails y, si lo activas, Airflow) y sube a S3 el código del pipeline (`pipeline.zip`, `run_glue.py`), los DAGs y el framework de Airflow. Para activar Airflow usa `make airflow-habilitar` (cambia la configuración y despliega). También se ejecuta solo en cada push a `main`.

10. **Snowflake (después de AWS).** El orden importa porque AWS y Snowflake se necesitan mutuamente:
    1. `bootstrap/snowflake/gen_key.sh` genera la llave; pega la clave pública en `bootstrap/snowflake/01_admin.sql` y ejecútalo en Snowsight como `ACCOUNTADMIN` (crea el resource monitor y el usuario `TERRAFORM_SVC`).
    2. En `infra/snowflake`: `cp terraform.tfvars.example terraform.tfvars`, `cp backend.hcl.example backend.hcl` y completa los valores (la llave privada queda en `~/.snowflake/keys/`).
    3. Desde la raíz, `make snowflake`: aplica `infra/snowflake`, guarda `storage_aws_iam_user_arn` y `storage_aws_external_id` en la configuración de S3 y aplica la fase 2 de AWS (trust policy del rol). No hay que copiar valores a mano.

    Detalle: [infra/snowflake/README.md](infra/snowflake/README.md).

11. **Ejecuta el pipeline.** En local: `make run-local STEP=all MES=2024-01`. En la nube: `make airflow-habilitar` (una vez; crea la VM), `make airflow-on`, abre el túnel con `make airflow-tunel`, usuario `admin` y contraseña de `make airflow-password`, y lanza el DAG `pipeline_taxi`. Guarda antes la conexión de Snowflake en el secreto `bigdata/snowflake` ([airflow/README.md](airflow/README.md)).

## Configuración por estudiante

Una sola fuente de verdad para Terraform de `infra/aws`: el archivo `s3://<TF_STATE_BUCKET>/config/aws.tfvars` (HCL, en el bucket de state, con versionado). Lo usan por igual `make deploy` (local) y `deploy.yml` / `ci.yml` (GitHub Actions), que lo descargan y lo pasan con `-var-file`. No hay variables de Terraform en `.env` ni en el fork.

Contenido típico:

```hcl
prefix                 = "bigdata"
aws_region             = "us-east-2"
alert_email            = "tu-correo@ejemplo.com"
enable_glue            = true
enable_airflow         = true
snowflake_iam_user_arn = "arn:aws:iam::...:user/..."   # lo pone make snowflake
snowflake_external_id  = "..."                          # lo pone make snowflake
```

- `make config`: muestra el archivo.
- `make airflow-habilitar` / `make airflow-deshabilitar`: cambian `enable_airflow` y despliegan. Apagar Airflow destruye la VM: el deploy lo exige con `CONFIRMAR_DESTRUCCION=true make airflow-deshabilitar`.
- `make snowflake`: copia los outputs de Snowflake. Con `SIN_DEPLOY=true` solo actualiza el archivo.
- Guardia de destrucción: `make deploy` y `deploy.yml` muestran el plan y abortan si elimina o reemplaza recursos, salvo que lo confirmes (`CONFIRMAR_DESTRUCCION=true` o el input `confirmar_destruccion` en el workflow manual). `make destroy` no usa esta guardia.
- Si el archivo no existe, `make deploy` falla con "Falta la configuración en S3. Corre 'make setup' en Code Editor."

## Targets de `make`

Ejecuta `make help` para ver la lista actualizada.

| Target | Qué hace |
|---|---|
| `make setup` | Verifica herramientas, crea `.venv`, valida la región de Snowflake, alinea `AWS_REGION` y crea la configuración de AWS en S3 si no existe |
| `make config` | Muestra la configuración de AWS guardada en S3 |
| `make doctor` | Diagnóstico: versiones, AWS, Snowflake, Terraform, OIDC |
| `make estado` | Estado de Airflow, últimos job runs de Glue, warehouse y costos |
| `make test` | `ruff check`, `ruff format --check`, `pytest` (y tests de DAGs si Airflow está instalado) |
| `make run-local` | Pipeline en local (`STEP=bronze\|silver\|gold\|all`, `MES=YYYY-MM`) |
| `make deploy` | `terraform apply` de `infra/aws` (con la guardia de destrucción) y sincronización de código, DAGs y framework a S3 |
| `make snowflake` | `terraform apply` de `infra/snowflake`, guarda sus outputs en S3 y aplica la fase 2 de AWS (`SIN_DEPLOY=true` omite el deploy) |
| `make airflow-habilitar` / `make airflow-deshabilitar` | `enable_airflow` = true / false en S3 y `make deploy` |
| `make airflow-on` / `make airflow-off` | Enciende / apaga la VM de Airflow |
| `make airflow-tunel` | Túnel SSM `localhost:8080` -> Airflow |
| `make airflow-password` | Usuario y contraseña de Airflow (Secrets Manager) |
| `make desbloquear` | Revierte la acción de Budgets (quita el Deny), con confirmación |
| `make snowflake-ampliar-cuota` | Sube la cuota del resource monitor (`CUOTA=N`) |
| `make destroy` | Vacía el lake y destruye Snowflake y AWS; opcionalmente el bootstrap y el state |

## Costos y apagado

Estimaciones aproximadas; verifica precios vigentes en la consola de AWS y de Snowflake.

- **Presupuesto**: el bootstrap crea `bigdata-monthly` (50 USD por defecto) con alertas al 50, 80 y 100 %. Terraform crea `bigdata-mensual`: al 60 % de gasto real, AWS Budgets adjunta una política Deny (`bigdata-bloqueo-presupuesto`) que impide iniciar jobs Glue e instancias EC2. Budgets actualiza el gasto como mucho una vez al día, así que no es un tope en tiempo real. Para revertirlo: `make desbloquear`.
- **Glue**: se paga por segundo de cómputo de los workers. Los jobs tienen máximo 2, 4 o 6 workers G.1X y tiempos límite de 10, 20 y 30 minutos, y como máximo 3 ejecuciones simultáneas.
- **Athena**: cada consulta se cancela al pasar de 1 GB escaneado.
- **VM de Airflow** (opcional): `m7i-flex.large` elegible en el plan gratuito. Se apaga sola a las 23:00 (hora de Bogotá). Apágala con `make airflow-off` cuando termines. La IP elástica pública puede tener un costo pequeño por hora aunque la VM esté apagada.
- **SageMaker Code Editor**: se apaga solo tras 60 minutos de inactividad.
- **Snowflake**: warehouse XS con `auto_suspend` de 60 s; el resource monitor `BIGDATA_RM` limita a 60 créditos al mes y suspende el warehouse al llegar al 100 %. Para ampliarlo: `make snowflake-ampliar-cuota CUOTA=<n>`.
- **Al terminar el curso**: `make destroy` (borra el lake, Snowflake y AWS y, si confirmas, el bootstrap y el bucket de state). Las cuentas de AWS y Snowflake siguen siendo tuyas.

## Troubleshooting

| Síntoma | Qué revisar |
|---|---|
| El stack falla con `EntityAlreadyExists` (OIDC) | La cuenta ya tiene el proveedor de GitHub: relanza el stack con `ExistingGitHubOidcProviderArn` ([docs/bootstrap.md](docs/bootstrap.md)) |
| GitHub Actions: `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Revisa `AWS_ROLE_ARN` y los IDs numéricos del bootstrap. Ejecuta el workflow **Debug OIDC** y compara el claim `sub` |
| `make setup` dice que Snowflake no está en AWS | Crea otra cuenta trial eligiendo AWS y `us-east-2` |
| `ci.yml` o `deploy.yml` fallan pidiendo `AWS_ROLE_ARN` o `TF_STATE_BUCKET` | Crea esos secrets en el fork (en PRs desde forks el plan se omite a propósito) |
| `Falta la configuración en S3. Corre 'make setup' en Code Editor.` | Corre `make setup` en el Code Editor; crea `config/aws.tfvars` |
| `El plan destruye recursos` en el deploy | Revisa la lista del plan. Si es intencional (p. ej. apagar Airflow), repite con `CONFIRMAR_DESTRUCCION=true` o el input `confirmar_destruccion` |
| `AccessDenied` al lanzar jobs Glue o encender la VM | Probablemente actuó el presupuesto: `make estado` y `make desbloquear` |
| Terraform: `AccessDenied` al crear un rol IAM | El rol debe llevar la boundary `<prefix>-boundary` (`permissions_boundary_arn`) |
| Un job Glue falla con `ModuleNotFoundError: pipeline` | Falta subir el código: `make deploy` (sube `pipeline.zip` con la carpeta `pipeline/`) |
| `make airflow-tunel` no abre el túnel | Instala `session-manager-plugin`; la VM debe estar encendida (`make airflow-on`) |
| No veo la UI de Airflow | Usa el túnel o autoriza tu IP con el workflow **Permitir IP** (máx. 3 IP; se elimina la más antigua) |
| El DAG falla en `cargar_gold` | Falta la conexión: guarda el JSON en el secreto `bigdata/snowflake` y reinicia la VM ([airflow/README.md](airflow/README.md)) |
| Terraform: `Error acquiring the state lock` | Otro apply está corriendo; espera o revisa que el apply anterior terminó |
| `make test` o `make run-local` fallan por Java | Instala Java 17 (versión con la que se validó PySpark 3.5) y revisa `java -version` |

## Estructura

```
bootstrap/    CloudFormation (AWS) y SQL/llaves (Snowflake)
infra/aws/    Terraform: lake, glue, airflow_vm, guardrails
infra/snowflake/  Terraform: warehouse, base, rol, integración S3
src/pipeline/ pipeline bronze/silver/gold (+ run_glue.py)
airflow/      docker-compose, framework y DAGs
tests/        pruebas del pipeline (pytest + PySpark local)
scripts/      implementación de los targets de make
docs/         bootstrap e integración
.github/workflows/  ci, deploy, airflow-on/off, permitir-ip, quitar-ips, debug-oidc
```
