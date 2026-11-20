# =============================================================================
# ============================= COMMON SUBMODULE ==============================
# =============================================================================

module "common" {
  source = "../common"

  qks_current_env        = var.qks_current_env
  qks_postgres_instances = var.qks_postgres_instances
}
