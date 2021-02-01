# ---------------------------------------------------------------------------------------------------------------------
# CRYPTO SETTINGS
# Configure the metadata for the CA certificate
# ---------------------------------------------------------------------------------------------------------------------
variable "algorithm" {
  type        = string
  description = "The algorithm to be used for the private key of the certificate."
}

variable "rsa_bits" {
  type        = number
  default     = 2048
  description = "When using the RSA algorithm this is the number of bits in the private key."
}

variable "ecdsa_curve" {
  type        = string
  default     = "P521"
  description = "When using the ECDSA algorithm this is the elliptic curve to use."
}

variable "ca_validity_period_hours" {
  type        = number
  default     = 86400  # 10 years
  description = "The number of hours the CA certificates are valid for."
}

variable "kubelet_validity_period_hours" {
  type        = number
  default     = 8640  # 1 year
  description = "The number of hours the kubelet certificates are valid for."
}

variable "kubelets" {
  type        = map(object({
    names = optional(list(string))
    ips   = optional(list(string))
  }))
  default     = {}
  description = "A list of kubelet names and IPs for which to generate kubelet certs. If at least one kubelet is present a kubelet CA will also be created."
}