resource "google_compute_region_instance_group_manager" "main" {
  name     = "${var.name}-mig"
  provider = google-beta
  region   = var.region
  version {
    instance_template = google_compute_instance_template.main.id
    name              = "primary"
  }
  named_port {
    name = "${var.name}-https-port"
    port = 443
  }
  named_port {
    name = "${var.name}-http-port"
    port = 80
  }
  auto_healing_policies {
    health_check      = google_compute_health_check.http.id
    initial_delay_sec = 300
  }
  base_instance_name = "${var.name}-instance"
  target_size        = 1
}

resource "google_compute_region_autoscaler" "main" {
  name   = "${var.name}-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.main.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 1
    cooldown_period = 90

    cpu_utilization {
      target = 0.8
    }
  }
}

resource "google_compute_instance_template" "main" {
  name_prefix  = "${var.name}-template"
  provider     = google-beta
  machine_type = var.machine_type
  tags         = [var.name]

  network_interface {
    network    = module.network_vpc.network_name
    subnetwork = module.network_vpc.subnets_ids[0]
    access_config {
    }
  }
  disk {
    source_image = data.google_compute_image.main.self_link
    auto_delete  = true
    boot         = true
  }

  metadata = {
    PORTAL_NAME                       = var.name
    PORTAL_RUNTIME_CONFIG             = google_runtimeconfig_config.main.id
    CLOUDSQL_INSTANCE_CONNECTION_NAME = google_sql_database_instance.master.connection_name
    PORTAL_FILESTORE                  = "${google_filestore_instance.main.networks[0].ip_addresses[0]}:/${google_filestore_instance.main.file_shares[0].name}"
    google-logging-enable             = "1"
    google-monitoring-enable          = "1"
    startup-script                    = "sudo /opt/apigee/scripts/startup.sh"
  }
  service_account {
    email  = google_service_account.main.email
    scopes = ["cloud-platform"]
  }
  lifecycle {
    create_before_destroy = true
  }
}