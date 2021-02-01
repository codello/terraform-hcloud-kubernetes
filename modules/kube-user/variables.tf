# ---------------------------------------------------------------------------------------------------------------------
# THE CLUSTER
# These variables provide information about the cluster we are connecting to. The cluster name and endpoint are not
# strictly required to generate client certificate but will be present in the kubeconfig.
# ---------------------------------------------------------------------------------------------------------------------
variable "cluster_name" {
  type        = string
  default     = "kubernetes"
  description = "The name of the cluster in the kubeconfig."
}

variable "cluster_endpoint" {
  type        = string
  description = "The public endpoint of the cluster's API server."
}

variable "kubernetes_ca" {
  type = object({
    algorithm = string
    cert      = string
    key       = string
  })
  description = "The Kubernetes CA used to create and verify user certificates."
}

# ---------------------------------------------------------------------------------------------------------------------
# USER DATA
# Provides information about the user/group for which a certificate will be generated.
# ---------------------------------------------------------------------------------------------------------------------
variable "username" {
  type        = string
  default     = "user"
  description = "The name of the user configuration."
}

variable "groups" {
  # FIXME: The groups should actually be a list. However this is currently blocked by
  # https://github.com/hashicorp/terraform-provider-tls/issues/3
  type        = string
  default     = null
  description = "A list of groups for the user."
}

# If you need to keep sensitive values out of your state files you can pass your own private key. Typically it is more
# useful to generate the whole certificate using other means (e.g. using Vault) and skipping this module altogether.
variable "private_key_pem" {
  type        = string
  default     = null
  description = "A private key used for the certificate."
}

# ---------------------------------------------------------------------------------------------------------------------
# CONTEXT
# The kubeconfig context.
# ---------------------------------------------------------------------------------------------------------------------
variable "context_name" {
  type        = string
  default     = null
  description = "The name of the generated context. If left unspecified a default name will be used."
}

# ---------------------------------------------------------------------------------------------------------------------
# CRYPTO SETTINGS
# Configure how the certificate will be generated.
# ---------------------------------------------------------------------------------------------------------------------
variable "validity_period_hours" {
  type        = number
  default     = 24
  description = "The time period for which the generated credentials will be valid."
}

variable "algorithm" {
  type        = string
  default     = "ECDSA"
  description = "The algorithm used for the certificate."
}

variable "rsa_bits" {
  type        = number
  default     = 2048
  description = "The number of RSA bits if algorithm is RSA."
}

variable "ecdsa_curve" {
  type        = string
  default     = "P521"
  description = "The ECDSA curve used for the ECDSA algorithm."
}
