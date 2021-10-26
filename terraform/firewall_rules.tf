resource "google_compute_firewall" "healthchecks" {
  name    = "allow-glb-healthchecks"
  network = module.network_vpc.network_name
  description = "Allow Load Balancer health checks"
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
   
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"]
  target_tags = [var.name]
}

resource "google_compute_firewall" "ssh" {
  name    = "allow-iap-ssh"
  network = module.network_vpc.network_name
  description = "Allow SSH via Cloud IAP"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
   
  source_ranges = ["35.235.240.0/20"]
  target_tags = [var.name]
}