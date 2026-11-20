locals {
  qks_tier = startswith(var.qks_current_env, "dev-") ? "development" : "production"
}

module "postgres_dev" {
  count  = local.qks_tier == "development" ? 1 : 0
  source = "./development"

  qks_current_env        = var.qks_current_env
  qks_postgres_instances = 1
}

module "postgres_prod" {
  count  = local.qks_tier == "production" ? 1 : 0
  source = "./production"

  qks_current_env        = var.qks_current_env
  qks_postgres_instances = 3
}

locals {
  tier = one(concat(module.postgres_dev, module.postgres_prod))
}