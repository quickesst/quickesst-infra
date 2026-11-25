locals {
  qks_tier = startswith(var.qks_current_env, "dev-") ? "development" : "production"
}

module "zitadel_dev" {
  count  = local.qks_tier == "development" ? 1 : 0
  source = "./development"

  qks_current_env                = var.qks_current_env
  qks_zitadel_pg_cluster         = var.qks_zitadel_pg_cluster
  qks_zitadel_pg_namespace       = var.qks_zitadel_pg_namespace
  qks_zitadel_pg_secret_name     = var.qks_zitadel_pg_secret_name
  qks_zitadel_pg_db_name         = var.qks_zitadel_pg_db_name
  qks_zitadel_external_domain    = var.qks_zitadel_external_domain
  qks_zitadel_ingress_class_name = var.qks_zitadel_ingress_class_name
}

module "zitadel_prod" {
  count  = local.qks_tier == "production" ? 1 : 0
  source = "./production"

  qks_current_env                = var.qks_current_env
  qks_zitadel_pg_cluster         = var.qks_zitadel_pg_cluster
  qks_zitadel_pg_namespace       = var.qks_zitadel_pg_namespace
  qks_zitadel_pg_secret_name     = var.qks_zitadel_pg_secret_name
  qks_zitadel_pg_db_name         = var.qks_zitadel_pg_db_name
  qks_zitadel_external_domain    = var.qks_zitadel_external_domain
  qks_zitadel_ingress_class_name = var.qks_zitadel_ingress_class_name
}

locals {
  tier = one(concat(module.zitadel_dev, module.zitadel_prod))
}
