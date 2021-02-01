locals {
  # The ClusterConfiguration object configures cluster components and bootstrapping behavior.
  cluster_configuration = merge(
    {
      apiVersion = "kubeadm.k8s.io/v1beta2"
      kind       = "ClusterConfiguration"

      clusterName          = var.name
      kubernetesVersion    = var.cluster_version
      controlPlaneEndpoint = local.api_endpoints[0]
      networking = merge(
        {
          podSubnet     = local.networking.pod_cidr
          serviceSubnet = local.networking.service_cidr
          dnsDomain     = local.networking.dns_domain
        },
      )

      certificatesDir = local.cert_dir
      apiServer = merge(
        length(local.api_endpoints) > 1 ? {
          certSANs = slice(local.api_endpoints, 1, length(local.api_endpoints))
        } : {},
        local.kubelet_ca_enabled ? {
          extraArgs = {
            kubelet-certificate-authority = "${local.cert_dir}/kubelet-ca.crt"
          }
        } : {}
      )

      controllerManager = yamldecode(var.controller_manager)
      scheduler         = yamldecode(var.scheduler)
    }
  )

  # The KubeletConfiguration will be uploaded into the cluster and applied by each kubelet when it joins.
  # This configuration should only contain settings that apply to every kubelet in the cluster.
  kubelet_configuration = merge(
    {
      apiVersion = "kubelet.config.k8s.io/v1beta1"
      kind       = "KubeletConfiguration"
    },
    yamldecode(var.kubelet_configuration),
    local.kubelet_ca_enabled ? {
      tlsCertFile       = local.kubelet_cert_path
      tlsPrivateKeyFile = local.kubelet_key_path
    } : {}
  )

  # The InitConfiguration configures the bootstrapping node (local.leader).
  init_configuration = {
    apiVersion       = "kubeadm.k8s.io/v1beta2"
    kind             = "InitConfiguration"
    nodeRegistration = local.node_registration[local.leader]
    localAPIEndpoint = local.local_api_endpoint[local.leader]
    bootstrapTokens  = []
  }

  # The JoinConfiguration configures how each node joins the cluster.
  join_configuration = { for node, config in local.nodes : node => merge(
    {
      apiVersion = "kubeadm.k8s.io/v1beta2"
      kind       = "JoinConfiguration"
      discovery = {
        file = { kubeConfigPath = local.kubeconfig_path }
      }
      nodeRegistration = local.node_registration[node]
    },
    config.role == "control-plane" ? {
      controlPlane = {
        localAPIEndpoint = local.local_api_endpoint[node]
      }
    } : {}
  ) }

  # The localAPIEndpoint is present for all control plane nodes.
  local_api_endpoint = {
    for node, config in local.control_plane_nodes : node => merge({
      advertiseAddress = local.network_enabled ? hcloud_server_network.network[node].ip : hcloud_server.servers[node].ipv4_address
      bindPort         = var.port
    })
  }

  # The nodeRegistration options configure how a node joins the cluster. This includes local kubelet configurations.
  node_registration = {
    for node, config in local.nodes : node => merge(
      {
        name   = node
        taints = coalesce(config.taints, var.node_defaults.taints, [])
        kubeletExtraArgs = merge(
          {
            node-ip        = local.network_enabled ? hcloud_server_network.network[node].ip : hcloud_server.servers[node].ipv4_address
            cloud-provider = "external"
          },
          length(coalesce(config.labels, var.node_defaults.labels, {})) > 0 ? {
            node-labels = join(",", [for key, value in coalesce(config.labels, var.node_defaults.labels, {}) : "${key}=${value}"])
          } : {},
          coalesce(config.kubelet_args, var.node_defaults.kubelet_args, {})
        )
        ignorePreflightErrors = coalesce(config.ignore_errors, var.node_defaults.ignore_errors, [])
      },
      (config.cri_socket != null) || (var.node_defaults.cri_socket != null) ? {
        criSocket = config.cri_socket != null ? config.cri_socket : var.node_defaults.cri_socket
      } : {}
    )
  }
}