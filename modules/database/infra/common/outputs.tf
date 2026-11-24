output "qks_postgres_role_secret_names" {
  value = { for role, secret in kubernetes_secret_v1.qks_ks_roles_password : role => secret.metadata[0].name }
}