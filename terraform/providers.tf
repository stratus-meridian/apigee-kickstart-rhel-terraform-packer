terraform {
  required_version = ">= 1.0"
  backend "gcs" {
    bucket  = "stratus-meridian-dev_tfstate"
    prefix  = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  region  = var.region
  project = var.project_id
}