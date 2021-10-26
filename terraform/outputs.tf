output "site_address" {
  value = google_compute_global_address.external_ip.address
}

output "username" {
  value = google_runtimeconfig_variable.site_basic_auth_user.value
  sensitive = true
}

output "password" {
  value = google_runtimeconfig_variable.site_basic_auth_password.value
  sensitive = true
}