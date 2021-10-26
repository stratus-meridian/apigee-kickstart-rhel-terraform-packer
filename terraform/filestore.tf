resource "google_filestore_instance" "main" {
  name = var.name
  zone = local.zone
  tier = "STANDARD"

  file_shares {
    capacity_gb = 1024
    name        = "fileshare"
  }

  networks {
    network = module.network_vpc.network_name
    modes   = ["MODE_IPV4"]
  }
}