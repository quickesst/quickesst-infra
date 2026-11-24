resource "random_password" "qks_postgres_roles_password" {
  for_each = local.qks_postgres_roles
  length   = 64
  special  = false

  # Critical resource: regenerating a password cuts the access of its consumer (Zitadel, ...).
  lifecycle {
    prevent_destroy = true
  }
}

resource "kubernetes_secret_v1" "qks_ks_roles_password" {
  for_each = local.qks_postgres_roles

  metadata {
    name      = "${replace(each.key, "_", "-")}-credentials"
    namespace = var.qks_database_namespace
    labels = {
      "cnpg.io/reload" = "true"
    }
  }

  type = "kubernetes.io/basic-auth"

  data = {
    username = each.key
    password = random_password.qks_postgres_roles_password[each.key].result
  }
}

resource "kubectl_manifest" "cluster_access" {
  server_side_apply = true
  field_manager     = local.qks_field_manager
  apply_only        = true

  yaml_body = yamlencode({
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = var.qks_database_cluster
      namespace = var.qks_database_namespace
    }
    spec = {
      managed = {
        roles = [for role in local.qks_postgres_roles : {
          name           = role
          ensure         = "present"
          login          = true
          passwordSecret = { name = kubernetes_secret_v1.qks_ks_roles_password[role].metadata[0].name }
        }]
      }
      postgresql = {
        pg_hba = concat(
          # hostssl: only TLS connections are accepted for application roles.
          [for db, owner in var.qks_database_values : "hostssl ${db} ${owner} all scram-sha-256"],
          # Reject everything else, encrypted or not.
          ["host all all all reject"]
        )
      }
    }
  })
}

resource "kubectl_manifest" "database" {
  for_each = var.qks_database_values

  yaml_body = yamlencode({
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Database"
    metadata = {
      name      = replace(each.key, "_", "-")
      namespace = var.qks_database_namespace
    }
    spec = {
      name    = each.key
      owner   = each.value
      cluster = { name = var.qks_database_cluster }
      # Deleting the Database resource keeps the database and its data (default, made explicit).
      databaseReclaimPolicy = "retain"
    }
  })

  depends_on = [kubectl_manifest.cluster_access]
}