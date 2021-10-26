resource "google_service_account" "main" {
  account_id   = "apigee-developer"
  display_name = "The Service Account for Compute Engine Instances"
}

resource "google_project_iam_member" "storage_object_viewer" {
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.main.email}"
}

resource "google_project_iam_member" "logging_log_wiewer" {
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.main.email}"
}

resource "google_project_iam_member" "monitoring_metric_writer" {
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.main.email}"
}

resource "google_project_iam_member" "runtimeconfig_admin" {
  role    = "roles/runtimeconfig.admin"
  member  = "serviceAccount:${google_service_account.main.email}"
}

resource "google_project_iam_member" "apigee_developer_admin" {
  role    = "roles/apigee.developerAdmin"
  member  = "serviceAccount:${google_service_account.main.email}"
}

resource "google_project_iam_member" "cloudsql_client" {
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.main.email}"
}