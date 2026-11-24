# =============================================================================
# ============================= COMMON SUBMODULE ==============================
# =============================================================================

module "common" {
  source = "../common"

  qks_current_env        = var.qks_current_env
  qks_database_cluster   = var.qks_database_cluster
  qks_database_namespace = var.qks_database_namespace
  qks_database_values    = var.qks_database_values
}
