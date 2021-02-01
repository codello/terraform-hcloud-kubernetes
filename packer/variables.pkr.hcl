variable "hcloud-token" {
  type        = string
  description = "A Hetzner Cloud token used to build the image. The token determines the project in which the built image will be available."
  sensitive   = true
}

variable "version" {
  type = string
  description = "The Kubernetes version to install."
}

variable "crio-version" {
  type = string
  default = null
  description = "The cri-o version. Defaults to major.minor of the Kubernetes version."
}
