# =============================================================================
# ============================ COMMON VARIABLES ===============================
# =============================================================================


variable "qks_current_env" {
  type        = string
  description = "Current Environment"
}

variable "qks_database_cluster" {
  type        = string
  description = "Database cluster name"
}

variable "qks_database_namespace" {
  type        = string
  description = "Database namespace name"
}

variable "qks_database_values" {
  type        = map(string)
  description = "Databases values (name, role)"
}