locals {
  api_endpoints = coalescelist(var.api_endpoints, [hcloud_server.servers[local.leader].ipv4_address, hcloud_server.servers[local.leader].ipv6_address])
  kubelet_ca_enabled = var.ca_certificates.kubelet != null
  network_enabled = var.private_network != null
  kubeconfig_path     = "/tmp/kubeconfig.yml"
  kubeadm_config_path = "/tmp/kubeadm.yml"

  networking = defaults(var.networking, {
    # The pod_cidr can be changed (even with flannel). However this is a commonly used value.
    pod_cidr     = "10.244.0.0/16"
    # The service_cidr is the kubeadm default.
    service_cidr = "10.96.0.0/12"
    # The dns_domain is the kubeadm default.
    dns_domain   = "cluster.local"
  })
}

resource "null_resource" "cluster" {
  # This resource only exists to provide a common trigger dependency for cluster  components. This avoids cyclic
  # dependencies.
  triggers = {
    name           = var.name
    kubernetes_ca  = sha1(var.ca_certificates.kubernetes.cert)
    etcd_ca        = sha1(var.ca_certificates.etcd.cert)
    front_proxy_ca = sha1(var.ca_certificates.front_proxy.cert)
    kubelet_ca     = sha1(var.ca_certificates.kubelet.cert)
    sa_keypair     = sha1(var.sa_keypair.public_key_pem)

    pod_cidr     = local.networking.pod_cidr
    service_cidr = local.networking.service_cidr
    dns_domain   = local.networking.dns_domain
  }
}

# The bootstrap dependencies technically don't do anything and could be removed. However in certain situations it may
# be useful to defer bootstrapping until some other resources have been created. Usually this can be solved via a
# module dependency. However if the other resources depend on the IPs of the nodes for example this would create a
# cyclic dependency. Notably this is the case for DNS entries.
#
# To solve this issue we offer bootstrap_dependencies as a way to defer bootstrapping until some other resources are
# created successfully.
resource "null_resource" "bootstrap_dependencies" {
  count    = length(var.bootstrap_dependencies)
  triggers = {
    value = var.bootstrap_dependencies[count.index]
  }
}

resource "null_resource" "bootstrap" {
  depends_on = [
    null_resource.bootstrap_dependencies,
    null_resource.certificates
  ]
  
  triggers = {
    cluster = null_resource.cluster.id
  }
  
  connection {
    user        = coalesce(local.nodes[local.leader].ssh_user, "kube")
    host        = hcloud_server.servers[local.leader].ipv4_address
    private_key = var.ssh_key.private_key
  }
  
  provisioner "file" {
    content = join("\n---\n", [
      yamlencode(local.cluster_configuration),
      yamlencode(local.init_configuration),
      var.kube_proxy_configuration,
      yamlencode(local.kubelet_configuration)
    ])
    destination = local.kubeadm_config_path
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo kubeadm init --config=${local.kubeadm_config_path}",
      "rm -f ${local.kubeadm_config_path}",
    ]
  }
}


resource "null_resource" "upgrade" {
  depends_on = [ null_resource.bootstrap, null_resource.bootstrap_dependencies ]

  triggers = {
    cluster = null_resource.cluster.id
    version = var.cluster_version

    # We use jsonencode here to get a normal form. yamlencode does not have a stable string representation (yet).
    kubelet_configuration    = sha1(jsonencode(local.kubelet_configuration))
    kube_proxy_configuration = sha1(var.kube_proxy_configuration)
    cluster_configuration    = sha1(jsonencode(local.cluster_configuration))
  }
  
  connection {
    user        = coalesce(local.nodes[local.leader].ssh_user, "kube")
    host        = hcloud_server.servers[local.leader].ipv4_address
    private_key = var.ssh_key.private_key
  }
  
  provisioner "file" {
    content = join("\n---\n", [
      yamlencode(local.cluster_configuration),
      var.kube_proxy_configuration,
      yamlencode(local.kubelet_configuration)
    ])
    destination = local.kubeadm_config_path
  }
  
  provisioner "remote-exec" {
    inline = [
      "version=$(sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf version --short | grep \"^Server Version: \" | cut -d' ' -f 3)",
      "if [ \"$version\" != \"${var.cluster_version}\" ]; then sudo kubeadm upgrade apply ${var.cluster_version} --yes --config=${local.kubeadm_config_path}; fi",
      "rm -rf ${local.kubeadm_config_path}"
    ]
  }
}


resource "null_resource" "join" {
  depends_on = [ null_resource.upgrade, null_resource.bootstrap_dependencies ]
  for_each   = local.nodes

  triggers = {
    # When the cluster ID changes it means that a new cluster has been created.
    cluster             = null_resource.cluster.id
    # When the server id changes we want to re-join the node
    server_id           = hcloud_server.servers[each.key].id
    # When a node changes its role it has to be rejoined
    role                = each.value.role
    # When the kubelet gets new certificates we have to reprovision the node.
    kubelet_certificate = sha1(var.kubelet_certs[each.key].cert)
    # When new certificates are deployed nodes are rejoined.
    certificates        = each.value.role == "control-plane" ? null_resource.certificates[each.key].id : null

    # These values are not actually necessary as triggers but this way we can use a destroy-provisioner.
    user         = coalesce(each.value.ssh_user, "kube")
    host         = hcloud_server.servers[each.key].ipv4_address
    private_key  = var.ssh_key.private_key
  }

  connection {
    user        = self.triggers.user
    host        = self.triggers.host
    private_key = self.triggers.private_key
  }
  
  provisioner "file" {
    content     = var.kubeconfig
    destination = local.kubeconfig_path
  }
  
  provisioner "file" {
    content = yamlencode(local.join_configuration[each.key])
    destination = local.kubeadm_config_path
  }
  
  provisioner "remote-exec" {
    inline = concat(
      [
        "test -f /etc/kubernetes/kubelet.conf || sudo kubeadm join --config=\"${local.kubeadm_config_path}\"",
        "rm -f \"${local.kubeadm_config_path}\" \"${local.kubeconfig_path}\""
      ],
      length(coalesce(each.value.annotations, {})) > 0 ? [
        "sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf annotate node ${each.key} ${
          join(" ", [for key,value in each.value.annotations: "${key}=${value}"])
        }"
      ] : []
    )
  }

  provisioner "remote-exec" {
    # This is kind of a workaround:
    # - On masters we can use the admin.conf kubeconfig to remove the node. All is good.
    # - On workers no kubeconfig with appropriate permissions exists. Instead we can use the kubelet's kubeconfig to
    #   drain the node and let the ccm take care of removing it from the cluster when the server is decomissioned.
    #
    # This will not work if we are re-joining the same worker node. Currently  the solution to this caveat is to delete
    # nodes before rejoining them.
    when   = destroy
    inline = concat(
      lookup(self.triggers, "role", null) == "control-plane" ? [
        "sudo cp /etc/kubernetes/admin.conf /tmp/admin.conf"
      ] : [],
      [
        "sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf drain ${each.key} --delete-local-data --ignore-daemonsets --force",
        "sudo kubeadm reset -f",
        "if sudo command -v iptables; then sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X; fi",
        "if sudo command -v ipvsadm; then sudo ipvsadm --clear; fi"
      ],
      lookup(self.triggers, "role", null) == "control-plane" ? [
        "sudo kubectl --kubeconfig=/tmp/admin.conf delete node ${each.key}",
        "sudo rm -f /tmp/admin.conf"
      ] : []
    )
  }
}
