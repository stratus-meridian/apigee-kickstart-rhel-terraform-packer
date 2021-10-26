module "gcp_apis" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "10.1.1"

  activate_apis = [
    "file.googleapis.com",
    "sql-component.googleapis.com",
    "serviceusage.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "runtimeconfig.googleapis.com",
    "secretmanager.googleapis.com"
  ]
  project_id = var.project_id
}