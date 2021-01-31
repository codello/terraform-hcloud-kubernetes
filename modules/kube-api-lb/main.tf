locals {
  # The actual node port to be used.
  node_port = coalesce(var.node_port, var.port)
}

resource "hcloud_load_balancer" "this" {
  name               = var.name
  load_balancer_type = var.type
  location           = var.location

  labels = var.hcloud_labels
}

resource "hcloud_load_balancer_service" "api" {
  load_balancer_id = hcloud_load_balancer.this.id
  protocol         = "tcp"
  listen_port      = var.port
  destination_port = local.node_port

  health_check {
    protocol = "http"
    port     = local.node_port
    interval = 15
    timeout  = 10
    retries  = 3
    http {
      path         = "/livez"
      tls          = true
      status_codes = ["2??"]
    }
  }
}

resource "hcloud_load_balancer_network" "network" {
  count = var.mode != "public" ? 1 : 0

  load_balancer_id        = hcloud_load_balancer.this.id
  subnet_id               = var.subnet_id
  enable_public_interface = var.mode == "bridge"
}

resource "hcloud_load_balancer_target" "control_plane" {
  depends_on = [hcloud_load_balancer_network.network]
  count      = var.control_plane_selector != null ? 1 : 0

  type             = "label_selector"
  label_selector   = var.control_plane_selector
  load_balancer_id = hcloud_load_balancer.this.id
  use_private_ip   = var.subnet_id != null
}
