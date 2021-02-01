terraform {
  required_version = ">= 0.14"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.24.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}
