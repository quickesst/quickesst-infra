locals {
  qks_tier = startswith(var.qks_current_env, "dev-") ? "development" : "production"
}

module "database_dev" {
  count  = local.qks_tier == "development" ? 1 : 0
  source = "./development"

  qks_current_env        = var.qks_current_env
  qks_database_cluster   = var.qks_database_cluster
  qks_database_namespace = var.qks_database_namespace
  qks_database_values    = var.qks_database_values
}

module "database_prod" {
  count  = local.qks_tier == "production" ? 1 : 0
  source = "./production"

  qks_current_env        = var.qks_current_env
  qks_database_cluster   = var.qks_database_cluster
  qks_database_namespace = var.qks_database_namespace
  qks_database_values    = var.qks_database_values
}

locals {
  tier = one(concat(module.database_dev, module.database_prod))
}