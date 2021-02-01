locals {
  ha_mode         = var.api_lb_type != null
  endpoint_regex  = "^(?P<address>[^:\\/]+)(?::(?P<port>\\d+))?(?P<path>:\\/.*)?$"
  endpoint_object = try(
    regex(local.endpoint_regex, var.api_endpoints[0]),
    {
      address = module.api_lb.public_ipv4
      port    = module.api_lb.port
      path    = ""
    },
    {
      address = module.cluster.node_info[module.cluster.leader].public_ipv4
      port    = var.port
      path    = ""
    }
  )
  endpoint = join("", [
    "${local.endpoint_object.address}:${coalesce(local.endpoint_object.port, var.port)}",
    local.endpoint_object.path != null ? local.endpoint_object.path : ""
  ])

  hcloud_labels = merge(var.remove_default_hcloud_labels ? {} : {
    kubernetes = ""
    cluster    = var.name
  }, var.hcloud_labels)
  networking = defaults(var.networking, {
    # The node_cidr is arbitrarily chosen.
    node_cidr    = "10.173.0.0/16"
    # The pod_cidr can be changed (even with flannel). However this is a commonly used value.
    pod_cidr     = "10.244.0.0/16"
  })
}
# ---------------------------------------------------------------------------------------------------------------------
# NETWORKING
# ---------------------------------------------------------------------------------------------------------------------
resource "hcloud_network" "network" {
  name     = "${var.name}-network"
  ip_range = local.networking.node_cidr
  labels   = local.hcloud_labels
}

resource "hcloud_network_subnet" "subnet" {
  network_id   = hcloud_network.network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = hcloud_network.network.ip_range
}

# ---------------------------------------------------------------------------------------------------------------------
# API LOAD BALANCER
# ---------------------------------------------------------------------------------------------------------------------
module "api_lb" {
  source = "./modules/kube-api-lb"
  count  = local.ha_mode ? 1 : 0

  name          = "${var.name}-api"
  type          = var.api_lb_type
  location      = var.location
  hcloud_labels = merge(var.remove_default_hcloud_labels ? {} : {
    service = "api"
  }, local.hcloud_labels)
  subnet_id     = hcloud_network_subnet.subnet.id

  port                   = var.port
  control_plane_selector = coalesce(var.control_plane_selector, join(",", compact([
    "kubernetes",
    "cluster=${var.name}",
    var.role_label != "" ? "${var.role_label}=control-plane" : ""
  ])))
}

# ---------------------------------------------------------------------------------------------------------------------
# CERTIFICATES & SECRETS
# This module stores the private keys of the cluster certificate authorities in the Terraform state file. If you don't
# want that you can create your own module, replacing all "module.ca" variables with your respective certificates.
# ---------------------------------------------------------------------------------------------------------------------
resource "tls_private_key" "ssh_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "hcloud_ssh_key" "ssh_key" {
  name       = "${var.name} SSH Key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

module "pki" {
  source = "./modules/kube-pki"

  algorithm = "ECDSA"
  rsa_bits  = 4096 # For the SA keypair

  kubelets = {
    for name,config in var.nodes : name => {
      ips = [
        module.cluster.node_info[name].cluster_ip,
        module.cluster.node_info[name].public_ipv4,
        module.cluster.node_info[name].public_ipv6
      ]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# KUBERNETES CLUSTER
# Creates the actual cluster resources. The "./modules/kube-cluster" module is the core of this module. It creates
# cloud servers and initializes them with kubeadm.
# ---------------------------------------------------------------------------------------------------------------------
module "cluster" {
  source     = "./modules/kube-cluster"
  depends_on = [ module.api_lb ]

  name            = var.name
  cluster_version = var.cluster_version
  api_endpoints   = length(var.api_endpoints) > 0 ? var.api_endpoints : (
                      local.ha_mode ? [module.api_lb[0].public_ipv4, module.api_lb[0].public_ipv6] : []
                    )

  networking      = local.networking
  port            = var.port
  private_network = {
    subnet_id = hcloud_network_subnet.subnet.id
  }

  leader        = var.leader
  nodes         = var.nodes
  node_defaults = merge(var.node_defaults, {
    location      = var.location
    hcloud_labels = local.hcloud_labels
  })
  role_label    = var.role_label
  ssh_key       = {
    id          = hcloud_ssh_key.ssh_key.id
    private_key = tls_private_key.ssh_key.private_key_pem
  }

  kubeconfig       = module.kubeadm_user.kubeconfig.rendered
  kubelet_certs    = module.pki.kubelet_certs
  sa_keypair       = module.pki.sa_keypair
  ca_certificates  = module.pki.ca_certificates

  bootstrap_dependencies   = var.bootstrap_dependencies
  kube_proxy_configuration = var.kube_proxy_configuration
  kubelet_configuration    = var.kubelet_configuration
  controller_manager       = var.controller_manager
  scheduler                = var.scheduler
}

# The kubeadm_user is used to join nodes to the cluster.
module "kubeadm_user" {
  source = "./modules/kube-user"
  
  cluster_name     = var.name
  cluster_endpoint = "https://${local.endpoint}"
  kubernetes_ca    = module.pki.ca_certificates["kubernetes"]

  username              = "kubeadm"
  groups                = "system:bootstrappers:kubeadm:default-node-token"
  validity_period_hours = 2
}

# The admin kubeconfig is provided for convenience (and used to install addons). If you manage your certificate
# authorities manually you might want to create this user in a different way.
module "admin_user" {
  source = "./modules/kube-user"
  
  cluster_name     = var.name
  cluster_endpoint = "https://${local.endpoint}"
  kubernetes_ca    = module.pki.ca_certificates["kubernetes"]
  
  username = "kubernetes-admin"
  groups   = "system:masters"
}

# ---------------------------------------------------------------------------------------------------------------------
# ADDONS
# Cluster addons are used to provide functionality inside the cluster. By installing a CNI plugin, a CCM and the
# Hetzner CSI driver we can create a cluster that provides most of the functionality that Kubernetes user expect.
# ---------------------------------------------------------------------------------------------------------------------
module "addons" {
  source     = "./modules/kube-addons"
  # This explicit dependency is useful when the cluster is upgraded. This way the cluster upgrade is performed before
  # addons are updated.
  depends_on = [ module.cluster ]

  cluster_id = module.cluster.id
  kubeconfig = module.admin_user.kubeconfig.rendered

  cloud_controller_manager = {
    enabled  = var.hcloud_token != null
    token    = var.hcloud_token
    pod_cidr = local.networking.pod_cidr
    network  = hcloud_network.network.id
  }

  csi_driver = {
    enabled = var.hcloud_token != null
    token   = var.hcloud_token
  }

  ssh_keys = {
    enabled     = true
    public_key  = tls_private_key.ssh_key.public_key_openssh
    private_key = tls_private_key.ssh_key.private_key_pem
  }

  calico = {
    enabled = var.cni_plugin == "calico"
  }

  flannel = {
    enabled  = var.cni_plugin == "flannel"
    pod_cidr = local.networking.pod_cidr
  }
}
