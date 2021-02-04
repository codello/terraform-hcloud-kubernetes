terraform {
  required_version = ">= 0.14"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.24.1"
    }
  }

  experiments = [module_variable_optional_attrs]
}
