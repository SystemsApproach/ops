terraform {
  required_version = ">= 0.13"
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = "= 1.15.1"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 3.65.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 2.1.2"
    }
  }
}

variable "rancher" {
  description = "Rancher credential"
  type = object({
    url        = string
    access_key = string
    secret_key = string
  })
}

variable "gcp_config" {
  description = "GCP project and network configuration"
  type = object({
    region          = string
    compute_project = string
    network_project = string
    network_name    = string
    subnet_name     = string
  })
}

provider "rancher2" {
  api_url    = var.rancher.url
  access_key = var.rancher.access_key
  secret_key = var.rancher.secret_key
}

provider "google" {
  # Provide GCP credential using GOOGLE_CREDENTIALS environment variable
  project = var.gcp_config.compute_project
  region  = var.gcp_config.region
}
