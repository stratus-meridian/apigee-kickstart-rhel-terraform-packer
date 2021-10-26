module "network_vpc" {
  source  = "terraform-google-modules/network/google"
  version = "3.3.0"

  network_name = "${var.name}-network"
  routing_mode = "GLOBAL"
  project_id   = var.project_id

  subnets = [
    {
      subnet_name           = "filestore"
      subnet_region         = var.region
      subnet_ip             = "10.0.0.0/24"
      subnet_private_access = "true"
      subnet_flow_logs      = "true"
    }
  ]
}

resource "google_compute_global_address" "external_ip" {
  name = "${var.name}-external"
}

resource "google_compute_global_address" "private_ip_address" {
  provider = google-beta

  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = module.network_vpc.network_name
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider = google-beta

  network                 = module.network_vpc.network_name
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}