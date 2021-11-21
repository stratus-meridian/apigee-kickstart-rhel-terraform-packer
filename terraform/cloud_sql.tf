resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "master" {
  provider = google-beta

  name             = "${var.name}-${random_id.db_name_suffix.hex}"
  database_version = "MYSQL_8_0"
  region           = var.region
  root_password    = random_string.db_root_password.result
  
  deletion_protection = true

  settings {
    tier              = var.db_tier
    availability_type = var.availability_type
    disk_size       = 15
    disk_type       = "PD_SSD"
    ip_configuration {
      ipv4_enabled    = true
      require_ssl     = true
    }
    backup_configuration {
      enabled                        = true
      binary_log_enabled             = true
      transaction_log_retention_days = 7
      location                       = var.region
    }
  }
}

resource "google_sql_user" "main" {
  name     = "${var.name}-user"
  instance = google_sql_database_instance.master.name
  password = random_string.db_user_password.result
}

resource "google_sql_database" "main" {
  name     = replace("${var.name}-db","-","_")
  instance = google_sql_database_instance.master.name
}
