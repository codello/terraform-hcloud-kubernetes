variable "kubectl_cmd" {
  type        = string
  default     = "kubectl"
  description = "The kubectl command. If the kubectl binary is not in the PATH you might need to modify this value. Use the special value DOWNLOAD to automatically download the binary."
}

# ---------------------------------------------------------------------------------------------------------------------
# CLUSTER SETTINGS
# Configure the cluster that these addons should be applied to
# ---------------------------------------------------------------------------------------------------------------------
variable "cluster_id" {
  type        = number
  default     = null
  description = "The ID of the cluster. If this changes addons are re-applied."
}

variable "cluster_endpoint" {
  type        = string
  description = "The address of the cluster in which addons are to be installed"
}

variable "credentials" {
  type = object({
    ca_cert     = string
    client_cert = string
    client_key  = string
  })
  description = "Connection information for the kubectl command."
  # TODO: Mark this as sensitive. Currently this causes an error.
  # sensitive   = true
}

# ---------------------------------------------------------------------------------------------------------------------
# ADDONS CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

# The Hetzner Cloud Controller Manager.
# https://github.com/hetznercloud/hcloud-cloud-controller-manager
variable "cloud_controller_manager" {
  type = object({
    enabled  = bool             # Install the CCM
    token    = string           # Cloud Token the CCM will use to authenticate.
    pod_cidr = string           # CIDR from which pod IPs are allocated.
    network  = optional(number) # ID of the Cloud Network
  })
  default = {
    enabled  = false
    token    = ""
    pod_cidr = ""
  }
  description = "Settings for the cloud controller manager."
  sensitive   = true
}

# The Hetzner CSI Driver
# https://github.com/hetznercloud/csi-driver
variable "csi_driver" {
  type = object({
    enabled = bool   # Install the CSI driver.
    token   = string # Cloud Token the CSI driver will use to authenticate.

    default_storage_class = optional(bool)   # Whether to make this the default storage class.
    storage_class_name    = optional(string) # The name of the storage class in the cluster.
  })
  default = {
    enabled = false
    token   = ""
  }
  description = "Settings for the hcloud csi driver."
  sensitive   = true
}

# SSH Keys stored inside the cluster.
variable "ssh_keys" {
  type = object({
    enabled     = bool   # Install SSH Keys
    public_key  = string # The public key
    private_key = string # The private key
  })
  default = {
    enabled     = false
    public_key  = ""
    private_key = ""
  }
  description = "Settings for in-cluster SSH-Keys."
  # sensitive   = true
}

# The Calico CNI plugin.
variable "calico" {
  type = object({
    enabled       = bool             # Install Calico
    ipam          = optional(string) # The IP address management mechanism. Either `calico-ipam` or `host-local`
    overlay       = optional(string) # The type of overlay network to use. `none`, `ipip` or `vxlan`.
    force_overlay = optional(bool)   # Whether to use the network overlay for all communications.
  })
  default = {
    enabled = false
  }
  description = "Settings for the Calico Addon."
}

# The flannel CNI plugin.
variable "flannel" {
  type = object({
    enabled  = bool   # Install Flannel
    pod_cidr = string # The subnet from which pod IPs are allocated.
  })
  default = {
    enabled  = false
    pod_cidr = ""
  }
  description = "Settings for the Flannel Addon."
}
