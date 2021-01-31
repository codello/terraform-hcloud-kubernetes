variable "bootstrap_dependencies" {
  type        = list(any)
  default     = []
  description = "Dependencies that need to exist before the cluster can be bootstrapped. This may be useful to defer the bootstrapping process until DNS records have propagated."
}

# ---------------------------------------------------------------------------------------------------------------------
# GENERAL CLUSTER SETTINGS
# ---------------------------------------------------------------------------------------------------------------------
variable "name" {
  type        = string
  default     = "kubernetes"
  description = "A name for the cluster. Changing the name requires the cluster to be recreated."
}

variable "cluster_version" {
  type        = string
  description = "The kubernetes version used to initialize new nodes. Upgrades are supported, downgrades are not. Upgrades will only upgrade the cluster itself, not the individual nodes."

  validation {
    condition     = substr(var.cluster_version, 0, 1) == "v"
    error_message = "The cluster_version value must start with the prefix 'v', e.g. v1.19.6."
  }
}

variable "api_endpoints" {
  type        = list(string)
  default     = null
  description = "The endpoints of the cluster control plane (DNS names or IP address, optionally with port). Required for HA configurations. The first endpoint will be used as the primary endpoint."

  validation {
    condition     = alltrue([for endpoint in var.api_endpoints : length(split("://", endpoint)) == 1])
    error_message = "Endpoints must be DNS names or IP addresses."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORKING
# Cluster networking mainly relates to the network inside the cluster, not the Hetzner cloud network associated with
# the cluster.
# ---------------------------------------------------------------------------------------------------------------------
variable "private_network" {
  type        = object({
    network_id = optional(number)
    subnet_id  = optional(string)
  })
  default     = null
  description = "The Hetzner Cloud network taht all nodes should join."
}

variable "networking" {
  type        = object({
    pod_cidr     = optional(string)
    service_cidr = optional(string)
    dns_domain   = optional(string)
  })
  default     = {}
  description = "Settings for the cluster network."
}

# ---------------------------------------------------------------------------------------------------------------------
# NODES
# ---------------------------------------------------------------------------------------------------------------------
variable "ssh_key" {
  type        = object({
    id          = string # The ID of the SSH key in the Hetzner Cloud.
    private_key = string # The private key.
  })
  description = "The SSH key to use when creating and configuring nodes."
  sensitive   = true
}

variable "role_label" {
  type        = string
  default     = "role"
  description = "The name of the label under which to attach the node role (empty string removes label)."
}

variable "port" {
  type        = number
  default     = 6443
  description = "The port on which the API server is served."
}

variable "leader" {
  type        = string
  default     = null
  description = "The leading master node that will bootstrap the cluster. Usually it is not required to set this variable. It may be necessary if you are using multiple masters in a non-HA configuration."
}

variable "node_defaults" {
  type        = object({
    image_id          = optional(string) # The ID of the image for this node. Overrides image_name and image_selector.
    image_name        = optional(string) # The name of the image for this node. Overrides image_selector.
    image_selector    = optional(string) # A Hetzner label selector that choses the image for this node.
    most_recent_image = optional(bool)   # Whether or not to chose the most recent image if multiple images match the image_selector.

    server_type       = optional(string)      # The type of server for the node.
    location          = optional(string)      # The location for the node. Each node has to have a location.
    hcloud_labels     = optional(map(string)) # Hetzner Cloud Labels to attach to the server.
    label_strategy    = optional(string)      # "merge" or "replace". Merges node labels with defaults or replaces defaults.
    keep_disk         = optional(string)      # Whether or not to keep the disk size on node upgrades.
    user_data         = optional(string)      # Custom user-data. If not provided a default will be used that may or may not be suitable for your image.
    ssh_user          = optional(string)      # The username used to connect to the server. Needs to be able to use passwordless sudo.

    cri_socket        = optional(string)       # The criSocket used by the node.
    kubelet_args      = optional(map(string))  # Additional arguments for the kubelet.
    ignore_errors     = optional(list(string)) # Preflight errors that should be ignored. Typically NumCPU for cx11 servers.
    role              = optional(string)       # The role of the node. Only 'control-plane' is supported.
    taints            = optional(list(object({ # Additional taints for the node. If specified for control plane nodes the respective taint is not applied automatically anymore.
      key    = string
      value  = string
      effect = string
    })))
    labels            = optional(map(string))  # Additional labels for the node.
    annotations       = optional(map(string)) # Additional annotations for the node.
  })
  default     = {}
  description = "Default values for all nodes."
}

variable "nodes" {
  # The key is the name of the node. For a description of the possible values see node_defaults.
  type        = map(object({
    image_id          = optional(string)
    image_name        = optional(string)
    image_selector    = optional(string)
    most_recent_image = optional(bool)

    server_type       = optional(string)
    location          = optional(string)
    ip                = optional(string)      # The private IP of the node.
    hcloud_labels     = optional(map(string))
    label_strategy    = optional(string)
    keep_disk         = optional(string)
    user_data         = optional(string)
    ssh_user          = optional(string)

    cri_socket        = optional(string)
    kubelet_args      = optional(map(string))
    ignore_errors     = optional(list(string))
    role              = optional(string)
    taints            = optional(list(object({
      key    = string
      value  = string
      effect = string
    })))
    labels            = optional(map(string))
    # TODO: Implement annotations
    annotations       = optional(map(string))
  }))
  description = "The nodes for the cluster."
}

# ---------------------------------------------------------------------------------------------------------------------
# KUBERNETES COMPONENTS
# ---------------------------------------------------------------------------------------------------------------------
variable "kube_proxy_configuration" {
  # Unfortunately mixed-type maps are not supported by terraform. As a solution we accept the config as a string.
  type        = string
  default     = <<-EOF
    apiVersion: kubeadm.config.k8s.io/v1alpha1
    kind: KubeProxyConfiguration
  })
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
# CERTIFICATE AUTHORITY SETTINGS
# ---------------------------------------------------------------------------------------------------------------------
variable "kubeconfig" {
  type        = string
  description = "The kubeconfig used by kubeadm. Must have appropriate permissions in the cluster."
  # sensitive   = true
}

# See https://kubernetes.io/docs/concepts/architecture/control-plane-node-communication/#apiserver-to-kubelet
variable "kubelet_ca" {
  type        = object({
    cert = string
  })
  default     = null
  description = "A certificate for the kubelet certificate authority. If enabled it is expected that all kubelets use certificates issued by this CA."
}

variable "kubelet_certs" {
  type        = map(object({
    cert = string # The certificate
    key  = string # The private key
  }))
  default     = {}
  description = "The kubelet certificates for the kubelets. Required if kubelet_ca is set."
  # sensitive   = true
}

variable "certificates" {
  type        = object({
    kubernetes_ca = object({
      cert      = string # The certificatet of the kubernetes CA.
      key       = string # The private key of the kubernetes CA.
    })
    etcd_ca = object({
      cert      = string # The certificate of the etcd CA.
      key       = string # The private key of the etcd CA.
    })
    front_proxy_ca = object({
      cert      = string # The certificate of the front proxy CA.
      key       = string # The private key of the fron proxy CA.
    })
  })
  description = "The certificate authorities used by the cluster."
  # sensitive   = true
}

variable "sa_keypair" {
  type        = object({
    public_key_pem  = string
    private_key_pem = string
  })
  description = "The keypair used to create service account credentials."
  # sensitive   = true
}