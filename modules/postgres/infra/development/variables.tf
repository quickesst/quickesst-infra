# =============================================================================
# ============================ COMMON VARIABLES ===============================
# =============================================================================

variable "qks_current_env" {
  type        = string
  description = "Current Environment"
}

variable "qks_postgres_instances" {
  type        = number
  description = "Number of postgres instance"
}