locals {
  domain_components = split(".", var.cluster_domain)
  zone = join(".", slice(local.domain_components, length(local.domain_components) - 2, length(local.domain_components)))
}

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

# TODO: Remove when hetznercloud/terraform-provider-hcloud#306 is solved.
# https://github.com/hetznercloud/terraform-provider-hcloud/issues/306
data "hcloud_image" "image" {
  with_selector = "kubernetes"
  with_status   = ["available"]
}


module "cluster" {
  source = "../../"
  
  name            = "kubernetes"
  cluster_version = "v1.19.6"
  location        = "nbg1"
  hcloud_token    = var.hcloud_k8s_token
  hcloud_labels   = {
    test = true
    revision = 3
  }
  
  bootstrap_dependencies = [time_sleep.dns_propagation.id]

  api_lb_type   = "lb11"
  api_endpoints = [cloudflare_record.kubernetes_api.hostname]

  # Until defaults work with maps we have to specify everything for every node.
  node_defaults = {
    image_id     = data.hcloud_image.image.id # Temporary fix for hetznercloud/terraform-provider-hcloud#306
    server_type  = "cpx11"
    keep_disk    = true
    cri_socket   = "/var/run/crio/crio.sock"
    kubelet_args = {
      cgroup-driver = "systemd"
    }
  }

  # TODO: Test Labels, Annotations and Taints
  leader = "master2"
  nodes = {
    master1 = { role = "control-plane" }
    master2 = { role = "control-plane" }
    master3 = { role = "control-plane" }
    worker1 = {}
    worker2 = {}
  }

  kube_proxy_configuration = yamlencode({
    apiVersion = "kubeproxy.config.k8s.io/v1alpha1"
    kind       = "KubeProxyConfiguration"
    mode       = "ipvs"
  })
}

resource "local_file" "kubeconfig" {
  sensitive_content = module.cluster.admin_kubeconfig.rendered
  filename          = pathexpand("~/.kube/config")
  file_permission   = "0600"
}
