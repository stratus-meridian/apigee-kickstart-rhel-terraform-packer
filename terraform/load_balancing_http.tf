resource "google_compute_backend_service" "http" {
  name             = "${var.name}-http-backend"
  port_name        = "${var.name}-http-port"
  protocol         = "HTTP"
  timeout_sec      = 180
  session_affinity = "GENERATED_COOKIE"
  enable_cdn       = false 

  health_checks = [google_compute_health_check.http.id]
  backend {
    group           = google_compute_region_instance_group_manager.main.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
    max_utilization = 0.8
  }
}

resource "google_compute_url_map" "http" {
  name            = "${var.name}-http"
  default_service = google_compute_backend_service.http.id
}

resource "google_compute_target_http_proxy" "http" {
  name    = "${var.name}-http"
  url_map = google_compute_url_map.http.id
}

/*
resource "google_compute_forwarding_rule" "http" {
  provider        = google-beta
  name            = "${var.name}-http"
  ip_address      = google_compute_address.external_ip.address
  region          = var.region
  port_range      = 80
  backend_service = google_compute_backend_service.http.id
}*/

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name}-http"
  provider              = google
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http.id
  ip_address            = google_compute_global_address.external_ip.id
}

resource "google_compute_health_check" "http" {
  name = "${var.name}-http-health-check"
  check_interval_sec  = 30
  healthy_threshold   = 2 
  unhealthy_threshold = 10
  timeout_sec         = 5

  http_health_check {
    request_path        = "/health-check"
    port = 80
  }
}