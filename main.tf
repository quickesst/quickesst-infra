# =============================================================================
# ================================= VARIABLES =================================
# =============================================================================

variable "qks_current_env" {
  type        = string
  description = "Current environment"
}

variable "qks_kubeconfig_path" {
  type        = string
  description = "Path of the kubeconfig used by the Kubernetes, Helm and kubectl providers"
  default     = "~/.kube/config"
}

variable "qks_ingress_class_name" {
  type        = string
  description = "Ingress class of the cluster ingress controller (traefik on k3s)"
}

variable "qks_zitadel_external_domain" {
  type        = string
  description = "Public domain of Zitadel (for example auth.example.com), recorded when the instance is created"
}

# =============================================================================
# ================================== TF CONF ==================================
# =============================================================================

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.4.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
  }

  backend "s3" {
    encrypt = true
    region  = "eu-west-3"
  }
}

# =============================================================================
# ================================= PROVIDERS =================================
# =============================================================================

provider "kubernetes" {
  config_path = var.qks_kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = var.qks_kubeconfig_path
  }
}

provider "kubectl" {
  config_path = var.qks_kubeconfig_path
}

# =============================================================================
# ================================== MODULES ==================================
# =============================================================================

module "qks-postgres" {
  source          = "./modules/postgres/infra"
  qks_current_env = var.qks_current_env
}

module "qks-database" {
  depends_on = [module.qks-postgres]

  source = "./modules/database/infra"

  qks_current_env        = var.qks_current_env
  qks_database_cluster   = module.qks-postgres.cluster_name
  qks_database_namespace = module.qks-postgres.namespace
  qks_database_values = {
    zitadel = "zitadel"
  }
}

module "qks-zitadel" {
  depends_on = [module.qks-database]

  source = "./modules/zitadel/infra"

  qks_current_env                = var.qks_current_env
  qks_zitadel_pg_cluster         = module.qks-postgres.cluster_name
  qks_zitadel_pg_namespace       = module.qks-postgres.namespace
  qks_zitadel_pg_secret_name     = module.qks-database.qks_postgres_role_secret_names["zitadel"]
  qks_zitadel_pg_db_name         = "zitadel"
  qks_zitadel_external_domain    = var.qks_zitadel_external_domain
  qks_zitadel_ingress_class_name = var.qks_ingress_class_name
}
