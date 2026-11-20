output "cluster_name" {
  value = local.qks_pg_service_name
}

output "namespace" {
  value = kubernetes_namespace_v1.postgres_namespace.metadata[0].name
}

output "field_manager" {
  value = local.qks_field_manager
}