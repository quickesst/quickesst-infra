resource "kubernetes_namespace_v1" "qks_zitadel_namespace" {
  metadata {
    name = local.qks_zitadel_namespace_name
  }
}

# Critical resource: losing the masterkey makes all encrypted Zitadel data unrecoverable,
# even with a database backup. Zitadel requires exactly 32 characters.
resource "random_password" "qks_zitadel_masterkey" {
  length  = 32
  special = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "kubernetes_secret_v1" "qks_zitadel_masterkey" {
  metadata {
    name      = local.qks_zitadel_masterkey_secret_name
    namespace = kubernetes_namespace_v1.qks_zitadel_namespace.metadata[0].name
  }

  data = {
    masterkey = random_password.qks_zitadel_masterkey.result
  }
}

resource "kubernetes_secret_v1" "qks_zitadel_config" {
  metadata {
    name      = local.qks_zitadel_config_secret_name
    namespace = kubernetes_namespace_v1.qks_zitadel_namespace.metadata[0].name
  }

  # The chart reads the key "config-yaml": any other key is silently ignored.
  data = {
    "config-yaml" = yamlencode({
      Database = {
        Postgres = {
          User = {
            Password = data.kubernetes_secret_v1.qks_zitadel_pg_credentials.data["password"]
          }
        }
      }
    })
  }
}

resource "helm_release" "qks_zitadel" {
  name       = local.qks_zitadel_service_name
  namespace  = kubernetes_namespace_v1.qks_zitadel_namespace.metadata[0].name
  repository = "https://charts.zitadel.com"
  chart      = "zitadel"
  version    = "10.4.0"
  wait       = true

  values = [yamlencode({
    image = {
      tag = local.qks_zitadel_image_tag
    }

    tools = {
      kubectl = {
        image = { tag = local.qks_zitadel_kubectl_tag }
      }
      wait4x = {
        image = { tag = local.qks_zitadel_wait4x_tag }
      }
    }

    # Restarts Zitadel when the role password changes.
    podAnnotations = {
      "checksum/db-password" = sha256(data.kubernetes_secret_v1.qks_zitadel_pg_credentials.data["password"])
    }

    # Only initialise Zitadel internals: the database and the role are created by the
    # database module, so the init job needs no PostgreSQL admin credentials.
    initJob = {
      command = "zitadel"
    }

    ingress = {
      enabled   = true
      className = var.qks_zitadel_ingress_class_name
      hosts = [{
        host  = var.qks_zitadel_external_domain
        paths = [{ path = "/", pathType = "Prefix" }]
      }]
    }

    login = {
      image = {
        tag = local.qks_zitadel_login_image_tag
      }
      ingress = {
        enabled   = true
        className = var.qks_zitadel_ingress_class_name
        hosts = [{
          host  = var.qks_zitadel_external_domain
          paths = [{ path = "/ui/v2/login", pathType = "Prefix" }]
        }]
      }
    }

    zitadel = {
      masterkeySecretName = kubernetes_secret_v1.qks_zitadel_masterkey.metadata[0].name
      configSecretName    = kubernetes_secret_v1.qks_zitadel_config.metadata[0].name
      configmapConfig = {
        # ExternalDomain and ExternalPort are recorded when the instance is created:
        # changing them later requires a fresh instance.
        ExternalDomain = var.qks_zitadel_external_domain
        ExternalPort   = var.qks_zitadel_external_secure ? 443 : 80
        ExternalSecure = var.qks_zitadel_external_secure

        # TLS is terminated at the ingress.
        TLS = {
          Enabled = false
        }

        Database = {
          Postgres = {
            Host     = local.qks_zitadel_pg_host
            Port     = 5432
            Database = var.qks_zitadel_pg_db_name
            User = {
              Username = data.kubernetes_secret_v1.qks_zitadel_pg_credentials.data["username"]
              SSL = {
                Mode = "require"
              }
            }
          }
        }
      }
    }
  })]
}
