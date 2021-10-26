# resource "google_compute_backend_service" "https" {
#   name             = "${var.name}-https-backend"
#   port_name        = "${var.name}-https-port"
#   protocol         = "HTTPS"
#   timeout_sec      = 180
#   session_affinity = "GENERATED_COOKIE"
#   enable_cdn       = false 

#   health_checks = [google_compute_health_check.https.id]
#   backend {
#     group           = google_compute_region_instance_group_manager.main.instance_group
#     balancing_mode  = "UTILIZATION"
#     capacity_scaler = 1.0
#     max_utilization = 0.8
#   }
# }

resource "google_compute_url_map" "https" {
  name            = "${var.name}-https"
  default_service = google_compute_backend_service.http.id
}

resource "google_compute_target_https_proxy" "https" {
  name             = "${var.name}-https"
  url_map          = google_compute_url_map.https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.https.id]
}

/*
resource "google_compute_forwarding_rule" "https" {
  provider        = google-beta
  name            = "${var.name}-https"
  ip_address      = google_compute_address.external_ip.address
  region          = var.region
  port_range      = 443
  backend_service = google_compute_backend_service.https.id
}*/

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.name}-https"
  provider              = google
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.https.id
  ip_address            = google_compute_global_address.external_ip.id
}

resource "google_compute_managed_ssl_certificate" "https" {
  name = "${var.name}-cert"

  managed {
    domains = [
      var.domain
    ]
  }
}

# resource "google_compute_health_check" "https" {
#   name                = "${var.name}-https-health-check"
#   check_interval_sec  = 30
#   healthy_threshold   = 2 
#   unhealthy_threshold = 10
#   timeout_sec         = 5

#   https_health_check {
#     request_path = "/health-check"
#     port = 443
#   }
# }