data "google_compute_zones" "available" {
  region = var.region
}

data "google_compute_image" "main" {
  name    = var.image_name
  project = var.project_id
}