locals {
  qks_cnpg_namespace_name = "cnpg-system"

  # PostgreSQL image pinned by tag and digest, from the official CloudNativePG catalog
  # (github.com/cloudnative-pg/artifacts, image-catalogs/catalog-minimal-trixie.yaml).
  qks_pg_image = "ghcr.io/cloudnative-pg/postgresql:18.7-202611122305-minimal-trixie@sha256:b98ae0b74a12f20ccff32219be0e33fdd35c7e2e8e73c8bff9173f1128e167d1"

  qks_pg_namespace_name = "postgres"
  qks_pg_service_name   = "postgresql"
  qks_field_manager     = "qks_postgres_instance"
}