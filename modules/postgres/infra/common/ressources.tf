resource "kubernetes_namespace_v1" "cnpg_system" {
  metadata {
    name = local.qks_cnpg_namespace_name
  }
}

resource "helm_release" "cnpg_operator" {
  name       = "cnpg"
  namespace  = kubernetes_namespace_v1.cnpg_system.metadata[0].name
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  version    = "0.29.1"
  wait       = true
}

resource "kubernetes_namespace_v1" "postgres_namespace" {
  metadata {
    name = local.qks_pg_namespace_name
  }
}

resource "kubectl_manifest" "postgres_cluster" {
  depends_on = [helm_release.cnpg_operator]

  server_side_apply = true
  field_manager     = local.qks_field_manager

  # Critical resource: destroying it deletes the PostgreSQL cluster and its data.
  lifecycle {
    prevent_destroy = true
  }

  wait_for {
    condition {
      type   = "Ready"
      status = "True"
    }
  }

  yaml_body = yamlencode({
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = local.qks_pg_service_name
      namespace = kubernetes_namespace_v1.postgres_namespace.metadata[0].name
    }
    spec = {
      imageName = local.qks_pg_image
      instances = var.qks_postgres_instances
      storage = {
        size = "8Gi"
      }
    }
  })
}