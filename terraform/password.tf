resource "random_string" "db_root_password" {
  length = 16
  special = false
}

resource "random_string" "db_user_password" {
  length = 16
  special = false
}

resource "random_string" "user_password" {
  length = 16
  special = false
}