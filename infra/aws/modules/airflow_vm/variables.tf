variable "prefix" {
  description = "Prefijo de nombres de recursos (Name = prefix-recurso)."
  type        = string
  default     = "bigdata"
}

variable "lake_bucket" {
  description = "Nombre del bucket del lake (code/, dags/, logs/ se leen desde aquí)."
  type        = string
}

variable "glue_job_arns" {
  description = "ARNs de los jobs de Glue que Airflow puede iniciar y consultar."
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "CIDRs (/32 IPv4 o /128 IPv6) autorizados a la UI de Airflow en 8080. Vacío = sin acceso."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for c in var.allowed_cidrs :
      can(cidrhost(c, 0)) &&
      (endswith(c, "/32") || endswith(c, "/128")) &&
      !contains(["0.0.0.0/0", "::/0"], c)
    ])
    error_message = "allowed_cidrs solo acepta CIDRs de host (/32 IPv4 o /128 IPv6). Prohibido 0.0.0.0/0 y ::/0."
  }
}

variable "instance_type" {
  description = "Tipo de instancia de la VM Airflow (solo tipos elegibles en free plan)."
  type        = string
  default     = "m7i-flex.large"

  validation {
    condition     = contains(["m7i-flex.large", "c7i-flex.large", "t3.small"], var.instance_type)
    error_message = "instance_type debe ser m7i-flex.large, c7i-flex.large o t3.small (elegibles en free plan)."
  }
}

variable "vpc_id" {
  description = "VPC de la VM. Null = VPC por defecto de la cuenta."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subred de la VM (debe pertenecer a vpc_id). Null = primera subred de la VPC."
  type        = string
  default     = null
}

variable "timezone" {
  description = "Zona horaria de la expresión cron del apagado programado."
  type        = string
  default     = "America/Bogota"
}

variable "stop_cron" {
  description = "Expresión cron de EventBridge Scheduler para apagar la instancia."
  type        = string
  default     = "cron(0 23 * * ? *)"
}

variable "permissions_boundary_arn" {
  description = "ARN de la permissions boundary que llevan todos los roles IAM del modulo."
  type        = string
}
