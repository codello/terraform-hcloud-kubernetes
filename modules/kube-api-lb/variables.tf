# ---------------------------------------------------------------------------------------------------------------------
# LOAD BALANCER SETTINGS
# These variables configure the load balancer resource
# ---------------------------------------------------------------------------------------------------------------------
variable "name" {
  type        = string
  description = "The name of the load balancer."
}

variable "type" {
  type        = string
  description = "The type of load balancer to create."
}

variable "location" {
  type        = string
  default     = null
  description = "The location of the load balancer. One of location and datacenter is required."
}

variable "hcloud_labels" {
  type        = map(string)
  default     = {}
  description = "Additional labels attached to the load balancer resource."
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORKING
# These variables configure how the load balancer integrates into your network.
# ---------------------------------------------------------------------------------------------------------------------
variable "mode" {
  type        = string
  default     = "bridge"
  description = "How the load balancer fits in networks. 'public' only uses public interfaces. 'private' only uses private interfaces and disables the public interface. 'bridge' accepts public traffic but balances it via private IPs."

  validation {
    condition     = contains(["public", "private", "bridge"], var.mode)
    error_message = "The mode must be public, private or bridge."
  }
}

variable "subnet_id" {
  type        = string
  default     = null
  description = "The subnet the load balancer is attached to."
}

variable "port" {
  type        = number
  default     = 6443
  description = "The port on which the kubernetes API is served."
}

variable "node_port" {
  type        = number
  default     = null
  description = "The port on which the nodes serve the kubernetes API. Defaults to var.port."
}

variable "control_plane_selector" {
  type        = string
  default     = "role=control-plane"
  description = "A Hetzner label selector that selects the control plane nodes."
}