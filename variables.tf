# ---------------------------------------------------------------------------------------------------------------------
# GENERAL CLUSTER SETTINGS
# Configures general cluster settings and defaults for all nodes.
# ---------------------------------------------------------------------------------------------------------------------
variable "name" {
  type        = string
  description = "The name of the cluster."
}

variable "cluster_version" {
  type        = string
  description = "The kubernetes version used to initialize new nodes. Upgrades are supported, downgrades are not. Upgrades will only upgrade the cluster itself, not the individual nodes."

  validation {
    condition     = substr(var.cluster_version, 0, 1) == "v"
    error_message = "The cluster_version value must start with the prefix 'v', e.g. v1.19.6."
  }
}

variable "location" {
  type        = string
  description = "The location of the cluster."
}

variable "hcloud_labels" {
  type        = map(string)
  default     = {}
  description = "Hetzner labels that should be attached to all resources."
}

variable "remove_default_hcloud_labels" {
  type        = bool
  default     = false
  description = "Whether to remove the default Hetzner cloud labels created by this module. Does not apply to the role label."
}

# ---------------------------------------------------------------------------------------------------------------------
# HIGH AVAILABILITY SETTINGS
# Configures settings that are required for high availability.
# ---------------------------------------------------------------------------------------------------------------------
variable "api_endpoints" {
  type        = list(string)
  default     = []
  description = "The endpoints of the cluster control plane (DNS names or IP address, optionally with port). Required for HA configurations."

  validation {
    condition     = alltrue([for endpoint in var.api_endpoints : length(split("://", endpoint)) == 1])
    error_message = "Endpoints must be DNS names or IP addresses."
  }
}

variable "control_plane_selector" {
  type        = string
  default     = null
  description = "Provide a custom control plane selector for the API load balancer."
}

variable "api_lb_type" {
  type        = string
  default     = null
  description = "The type of load balancer to create for the API."
}

variable "port" {
  type        = number
  default     = 6443
  description = "The port on which the API server is served."
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORKING
# ---------------------------------------------------------------------------------------------------------------------
variable "networking" {
  type = object({
    node_cidr    = optional(string)
    pod_cidr     = optional(string)
    service_cidr = optional(string)
    dns_domain   = optional(string)
  })
  default     = {}
  description = "Settings for the cluster network."
}

# ---------------------------------------------------------------------------------------------------------------------
# NODES
# The node configuration is mainly copied from ./modules/kube-cluster/variables.tf
# ---------------------------------------------------------------------------------------------------------------------
variable "leader" {
  type        = string
  default     = null
  description = "The leading master node that will bootstrap the cluster. Usually it is not required to set this variable. It may be necessary if you are using multiple masters in a non-HA configuration."
}

variable "node_defaults" {
  type = object({
    image_id          = optional(string) # The ID of the image for this node. Overrides image_name and image_selector.
    image_name        = optional(string) # The name of the image for this node. Overrides image_selector.
    image_selector    = optional(string) # A Hetzner label selector that choses the image for this node.
    most_recent_image = optional(bool)   # Whether or not to chose the most recent image if multiple images match the image_selector.

    server_type   = optional(string)      # The type of server for the node.
    hcloud_labels = optional(map(string)) # Hetzner Cloud Labels to attach to the server.
    role_label    = optional(string)      # The name of the label under which to attach the node role (empty string removes label).
    keep_disk     = optional(string)      # Whether or not to keep the disk size on node upgrades.
    user_data     = optional(string)      # Custom user-data. If not provided a default will be used that may or may not be suitable for your image.
    ssh_user      = optional(string)      # The username used to connect to the server. Needs to be able to use passwordless sudo.

    kubelet_args  = optional(map(string))  # Additional arguments for the kubelet.
    ignore_errors = optional(list(string)) # Preflight errors that should be ignored. Typically NumCPU for cx11 servers.
    role          = optional(string)       # The role of the node. Only 'control-plane' is supported.
    taints = optional(list(object({        # Additional taints for the node. If specified for control plane nodes the respective taint is not applied automatically anymore.
      key    = string
      value  = string
      effect = string
    })))
    labels      = optional(map(string)) # Additional labels for the node.
    annotations = optional(map(string)) # Additional annotations for the node.
  })
  default     = {}
  description = "Default values for all nodes."
}

variable "nodes" {
  # The key is the name of the node. For a description of the possible values see node_defaults.
  type = map(object({
    image_id          = optional(string)
    image_name        = optional(string)
    image_selector    = optional(string)
    most_recent_image = optional(bool)

    server_type   = optional(string)
    location      = optional(string)
    ip            = optional(string) # The private IP of the node.
    hcloud_labels = optional(map(string))
    role_label    = optional(string)
    keep_disk     = optional(string)
    user_data     = optional(string)
    ssh_user      = optional(string)

    kubelet_args  = optional(map(string))
    ignore_errors = optional(list(string))
    role          = optional(string)
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })))
    labels      = optional(map(string))
    annotations = optional(map(string))
  }))
  description = "The nodes for the cluster."
}

variable "role_label" {
  type        = string
  default     = "role"
  description = "The name of the label under which to attach the node role (empty string removes label)."
}

# ---------------------------------------------------------------------------------------------------------------------
# OTHER CLUSTER CONFIGURATIONS
# These configurations are passed to the ./modules/kube-cluster module.
# ---------------------------------------------------------------------------------------------------------------------
variable "bootstrap_dependencies" {
  type        = list(any)
  default     = []
  description = "Dependencies that need to exist before the cluster can be bootstrapped. This may be useful to defer the bootstrapping process until DNS records have propagated."
}

variable "kube_proxy_configuration" {
  # Unfortunately mixed-type maps are not supported by terraform. As a solution we accept the config as a string.
  type        = string
  default     = <<-EOF
    apiVersion: kubeadm.config.k8s.io/v1alpha1
    kind: KubeProxyConfiguration
  EOF
  description = "The cluster-wide KubeProxyConfiguration."

  validation {
    condition     = can(yamldecode(var.kube_proxy_configuration))
    error_message = "The kube_proxy_configuration must be a valid yaml document."
  }
}

variable "kubelet_configuration" {
  # Unfortunately mixed-type maps are not supported by terraform. As a solution we accept the config as a string.
  type        = string
  default     = "{}"
  description = "The cluster-wide KubeletConfiguration. Some values are overridden by the module."

  validation {
    condition     = can(yamldecode(var.kubelet_configuration))
    error_message = "The kubelet_configuration must be a valid yaml document."
  }
}

variable "controller_manager" {
  # Unfortunately mixed-type maps are not supported by terraform. As a solution we accept the config as a string.
  type        = string
  default     = "{}"
  description = "Extra configuration for the controller manager."

  validation {
    condition     = can(yamldecode(var.controller_manager))
    error_message = "The controller_manager must be a valid yaml document."
  }
}

variable "scheduler" {
  # Unfortunately mixed-type maps are not supported by terraform. As a solution we accept the config as a string.
  type        = string
  default     = "{}"
  description = "Extra configuration for the scheduler."

  validation {
    condition     = can(yamldecode(var.scheduler))
    error_message = "The scheduler must be a valid yaml document."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ADDON CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------
variable "kubectl_cmd" {
  type        = string
  default     = "kubectl"
  description = "The kubectl command to install addons. Override if kubectl is not in the PATH."
}

variable "hcloud_token" {
  type        = string
  default     = null
  description = "The token used by the Hetzner CCM and CSI driver."
  sensitive   = true
}

variable "cni_plugin" {
  type        = string
  default     = "calico"
  description = "The CNI plugin to install."

  validation {
    condition     = contains(["calico", "flannel", "none"], var.cni_plugin)
    error_message = "The cni_plugin must be either calico, flannel or none."
  }
}
