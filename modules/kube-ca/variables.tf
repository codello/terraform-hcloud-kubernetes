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

variable "common_name" {
  type        = string
  description = "The CN of the generated certificate."
}

variable "validity_period_hours" {
  type        = number
  default     = 86400
  description = "The number of hours the certificate is valid for."
}