resource "google_secret_manager_secret" "credentials" {
  secret_id = var.name
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "secret" {
  secret      = google_secret_manager_secret.credentials.id
  secret_data = <<EOT
username = ${base64decode(google_runtimeconfig_variable.site_basic_auth_user.value)}
password = ${base64decode(google_runtimeconfig_variable.site_basic_auth_password.value)}
EOT

}