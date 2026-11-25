output "namespace" {
  value = kubernetes_namespace_v1.qks_zitadel_namespace.metadata[0].name
}
