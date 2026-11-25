# =============================================================================
# ============================ COMMON VARIABLES ===============================
# =============================================================================

variable "qks_current_env" {
  type        = string
  description = "Current environment"
}

variable "qks_zitadel_pg_cluster" {
  type        = string
  description = "Name of the CloudNativePG cluster, prefix of its read-write service"
}

variable "qks_zitadel_pg_namespace" {
  type        = string
  description = "Namespace of the PostgreSQL cluster and of the Zitadel role secret"
}

variable "qks_zitadel_pg_secret_name" {
  type        = string
  description = "Kubernetes secret holding the username and password of the Zitadel PostgreSQL role"
}

variable "qks_zitadel_pg_db_name" {
  type        = string
  description = "Name of the Zitadel PostgreSQL database"
}

variable "qks_zitadel_external_domain" {
  type        = string
  description = "Public domain of Zitadel, recorded when the instance is created"
}

variable "qks_zitadel_ingress_class_name" {
  type        = string
  description = "Ingress class of the cluster ingress controller (traefik on k3s)"
}

variable "qks_zitadel_external_secure" {
  type        = bool
  description = "Whether Zitadel is reached over HTTPS (TLS terminated at the ingress)"
}
