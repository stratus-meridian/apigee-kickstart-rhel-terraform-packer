variable "project_id" {}

variable "name" {}

variable "image_name" {}

variable "region" {}

variable "domain" {}

variable "machine_type" {
    default = "e2-standard-2"
}

variable "db_tier" {
    default = "db-n1-standard-1"
}

variable "availability_type" {
    default = "ZONAL"
}