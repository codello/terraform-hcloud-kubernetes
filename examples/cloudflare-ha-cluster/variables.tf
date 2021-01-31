variable "cloudflare_api_token" {
  type        = string
  description = "The CloudFlare API token."
}

variable "hcloud_token" {
  type        = string
  description = "The Hetzner Cloud API token to be used for creating the cluster resources."
}

variable "hcloud_k8s_token" {
  type        = string
  description = "The Hcloud token used for the cluster."
}

variable "cluster_domain" {
    type        = string
    description = "The domain where the cluster will be available."
}
