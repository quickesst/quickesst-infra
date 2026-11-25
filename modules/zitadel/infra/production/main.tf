module "common" {
  source = "../common"

  qks_current_env                = var.qks_current_env
  qks_zitadel_pg_cluster         = var.qks_zitadel_pg_cluster
  qks_zitadel_pg_namespace       = var.qks_zitadel_pg_namespace
  qks_zitadel_pg_secret_name     = var.qks_zitadel_pg_secret_name
  qks_zitadel_pg_db_name         = var.qks_zitadel_pg_db_name
  qks_zitadel_external_domain    = var.qks_zitadel_external_domain
  qks_zitadel_ingress_class_name = var.qks_zitadel_ingress_class_name
  qks_zitadel_external_secure    = true
}
