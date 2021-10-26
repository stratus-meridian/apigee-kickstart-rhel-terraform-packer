resource "google_runtimeconfig_config_iam_binding" "binding" {
  config = google_runtimeconfig_config.main.name
  role = "roles/viewer"
  members = [
    "serviceAccount:${google_service_account.main.email}"
  ]
}

resource "google_runtimeconfig_config" "main" {
  provider    = google-beta
  name        = "${var.name}-config"
  description = "Runtime configuration values"
}

resource "google_runtimeconfig_variable" "db_username" {
  parent = google_runtimeconfig_config.main.name
  name   = "db/username"
  value  = base64encode(google_sql_user.main.name)
}

resource "google_runtimeconfig_variable" "db_name" {
  parent = google_runtimeconfig_config.main.name
  name   = "db/name"
  value  = base64encode(google_sql_database.main.name)
}

resource "google_runtimeconfig_variable" "db_password" {
  parent = google_runtimeconfig_config.main.name
  name   = "db/password"
  value  = base64encode(random_string.db_user_password.result)
}

resource "google_runtimeconfig_variable" "site_basic_auth_enabled" {
  parent = google_runtimeconfig_config.main.name
  name   = "site_basic_auth/enabled"
  value  = base64encode("1")
}

resource "google_runtimeconfig_variable" "site_basic_auth_user" {
  parent = google_runtimeconfig_config.main.name
  name   = "site_basic_auth/user"
  value  = base64encode("admin")
}

resource "google_runtimeconfig_variable" "site_basic_auth_password" {
  parent = google_runtimeconfig_config.main.name
  name   = "site_basic_auth/password"
  value  = base64encode(random_string.user_password.result)
}