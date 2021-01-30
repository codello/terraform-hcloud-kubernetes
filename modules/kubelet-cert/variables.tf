variable "kubelet_ca" {
  type = object({
    algorithm = string # The algorithm of the CA.
    cert      = string # The CA certificate.
    key       = string # The CA private key.
  })
  description = "The CA from which kubelet certificates are generated."
}

variable "algorithm" {
  type        = string
  default     = "RSA"
  description = "The algorithm used for the certificate."
}

variable "ecdsa_curve" {
  type        = string
  default     = "P521"
  description = "The ECDSA curve to use."
}

variable "rsa_bits" {
  type        = number
  default     = 2048
  description = "The number of bits for the RSA key."
}

variable "names" {
  type        = list(string)
  description = "The DNS names under which the kubelet is reachable."

  validation {
    condition     = length(var.names) > 0
    error_message = "The names of the node must not be empty."
  }
}

variable "ips" {
  type        = list(string)
  description = "The IP addresses of the node."

  validation {
    condition     = length(var.ips) > 0
    error_message = "The ips of the node must not be empty."
  }
}

variable "validity_period_hours" {
  type        = number
  default     = 8760
  description = "The number of hours the certificate is valid for."
}
