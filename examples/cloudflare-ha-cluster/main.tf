locals {
  # If the domain is abc.domain.tld, we get zone as domain.tld
  domain_components = split(".", var.cluster_domain)
  zone              = join(".", slice(local.domain_components, length(local.domain_components) - 2, length(local.domain_components)))
}

# Create the CloudFlare records and let them propagate. For Hetzner Cloud networks 3m is usually enough time.
# Increment or decrement as needed.

data "cloudflare_zones" "zones" {
  filter {
    name = local.zone
  }
}

resource "cloudflare_record" "kubernetes_api" {
  zone_id = data.cloudflare_zones.zones.zones[0].id
  name    = var.cluster_domain
  type    = "A"
  value   = module.cluster.ipv4_address
  ttl     = 120
}

resource "time_sleep" "dns_propagation" {
  triggers = {
    hostname = cloudflare_record.kubernetes_api.hostname
    address  = cloudflare_record.kubernetes_api.value
  }

  create_duration = "3m"
}

# The actual cluster.
module "cluster" {
  source = "../../"

  name            = "kubernetes"
  cluster_version = "v1.19.6"
  location        = "nbg1"
  hcloud_token    = var.hcloud_k8s_token

  bootstrap_dependencies = [time_sleep.dns_propagation.id]

  api_lb_type   = "lb11"
  api_endpoints = [cloudflare_record.kubernetes_api.hostname]

  node_defaults = {
    server_type  = "cpx11"
    kubelet_args = { cgroup-driver = "systemd" }
  }

  # TODO: Test Labels, Annotations and Taints
  nodes = {
    master1 = { role = "control-plane" }
    master2 = { role = "control-plane" }
    master3 = { role = "control-plane" }
    worker1 = {}
    worker2 = {}
  }
}

# We store the kubeconfig at ~/.kube/config so the cluster is immediately usable. This is probably not something you
# want to do if you regularly work with multiple clusters.
resource "local_file" "kubeconfig" {
  sensitive_content = module.cluster.admin_kubeconfig.rendered
  filename          = pathexpand("~/.kube/config")
  file_permission   = "0600"
}
