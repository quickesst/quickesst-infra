# The role secret lives in the PostgreSQL namespace: a pod cannot mount it from another
# namespace, so its password is copied into the Zitadel configuration secret.
data "kubernetes_secret_v1" "qks_zitadel_pg_credentials" {
  metadata {
    name      = var.qks_zitadel_pg_secret_name
    namespace = var.qks_zitadel_pg_namespace
  }
}
