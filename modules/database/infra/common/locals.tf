locals {
  qks_postgres_roles = toset(values(var.qks_database_values))

  # Field manager used to patch the PostgreSQL cluster (managed roles and pg_hba) with
  # server-side apply, without taking ownership of the fields set by the postgres module.
  qks_field_manager = "qks-postgres-access"
}
