locals {
  qks_zitadel_namespace_name        = "zitadel"
  qks_zitadel_service_name          = "zitadel"
  qks_zitadel_masterkey_secret_name = "qks-zitadel-masterkey"
  qks_zitadel_config_secret_name    = "qks-zitadel-config"

  # Read-write service created by CloudNativePG, always pointing to the primary instance.
  qks_zitadel_pg_host = "${var.qks_zitadel_pg_cluster}-rw.${var.qks_zitadel_pg_namespace}.svc"

  # Images pinned by tag and digest (multi-arch index). Zitadel and its login UI match the
  # chart appVersion; the tool images replace the chart defaults, which are not pinned
  # (kubectl defaults to the cluster version, wait4x to a minor tag).
  qks_zitadel_image_tag       = "v4.19.2@sha256:956a298405189a8f6cd4ec92e8828b1bd10caa7da8b139c39d251d7053e33784"
  qks_zitadel_login_image_tag = "v4.19.2@sha256:ee98f024ddbebce788a7faf5a4b5571d20cbddf3bca8d3923091c424f2855737"
  qks_zitadel_kubectl_tag     = "1.37.2@sha256:7a82aeefea3d554a43a8676b137f2b88bae6c1fe11c13862b191b3a086cc28c0"
  qks_zitadel_wait4x_tag      = "3.6.0@sha256:bec7ac18547781d854562c3729d3195c3880116d6758c49fdf4573ad58805f14"
}
