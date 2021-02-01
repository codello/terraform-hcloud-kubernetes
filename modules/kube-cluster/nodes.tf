# TODO: Replace coalesce calls with defaults function when #27385 is resolved.
# https://github.com/hashicorp/terraform/issues/27385
locals {
  leader = var.leader != null ? var.leader : keys(local.control_plane_nodes)[0]
  nodes = {
    for name, config in var.nodes : name => merge(var.node_defaults, config)
  }
  control_plane_nodes = {
    for name, config in local.nodes : name => config if config.role == "control-plane"
  }

  kubelet_cert_path = "/var/lib/kubelet/pki/kubelet.crt"
  kubelet_key_path  = "/var/lib/kubelet/pki/kubelet.key"
  cert_dir          = "/etc/kubernetes/pki"
}

data "template_file" "image_selector" {
  for_each = local.nodes

  template = coalesce(each.value.image_selector, var.node_defaults.image_selector, "kubernetes")
  vars = {
    cluster_name    = var.name
    cluster_version = var.cluster_version
    node_name       = each.key
  }
}

data "hcloud_image" "image" {
  for_each = local.nodes

  id            = each.value.image_id != null ? each.value.image_id : var.node_defaults.image_id       # coalesce(each.value.image_id, var.node_defaults.image_id)
  name          = each.value.image_name != null ? each.value.image_name : var.node_defaults.image_name # coalesce(each.value.image_name, var.node_defaults.image_name)
  with_selector = data.template_file.image_selector[each.key].rendered
  with_status   = ["available"]
  most_recent   = coalesce(each.value.most_recent_image, var.node_defaults.most_recent_image, false)
}

resource "hcloud_server" "servers" {
  for_each = local.nodes

  name        = each.key
  server_type = coalesce(each.value.server_type, var.node_defaults.server_type)
  image       = data.hcloud_image.image[each.key].id
  location    = coalesce(each.value.location, var.node_defaults.location)
  ssh_keys    = [var.ssh_key.id]
  keep_disk   = coalesce(each.value.keep_disk, var.node_defaults.keep_disk, false)
  user_data   = coalesce(each.value.user_data, var.node_defaults.user_data, file("${path.module}/user-data.yaml"))
  labels = merge(
    var.role_label != "" ? { (var.role_label) = each.value.role } : {},
    coalesce(each.value.label_strategy, var.node_defaults.label_strategy, "merge") == "merge" ? var.node_defaults.hcloud_labels : {},
    each.value.hcloud_labels
  )
}

resource "hcloud_server_network" "network" {
  for_each = local.network_enabled ? local.nodes : {}

  server_id  = hcloud_server.servers[each.key].id
  network_id = var.private_network.network_id
  subnet_id  = var.private_network.subnet_id
  ip         = each.value.ip
}

resource "null_resource" "kubelet_certificate" {
  for_each = local.kubelet_ca_enabled ? local.nodes : {}

  triggers = {
    cluster     = null_resource.cluster.id
    server_id   = hcloud_server.servers[each.key].id
    ca_cert     = sha1(var.ca_certificates["kubelet"].cert)
    certificate = sha1(var.kubelet_certs[each.key].cert)
    private_key = sha1(var.kubelet_certs[each.key].key)
  }

  connection {
    user        = coalesce(each.value.ssh_user, "kube")
    host        = hcloud_server.servers[each.key].ipv4_address
    private_key = var.ssh_key.private_key
  }

  provisioner "file" {
    content = join("\n", [
      var.kubelet_certs[each.key].cert,
      var.ca_certificates["kubelet"].cert
    ])
    destination = "/tmp/kubelet.crt"
  }

  provisioner "file" {
    content     = var.kubelet_certs[each.key].key
    destination = "/tmp/kubelet.key"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${dirname(local.kubelet_cert_path)} ${dirname(local.kubelet_key_path)}",
      "sudo chown root:root ${dirname(local.kubelet_cert_path)} ${dirname(local.kubelet_key_path)}",
      "sudo chmod 0750 ${dirname(local.kubelet_cert_path)} ${dirname(local.kubelet_key_path)}",
      "sudo mv /tmp/kubelet.crt ${local.kubelet_cert_path}",
      "sudo mv /tmp/kubelet.key ${local.kubelet_key_path}",
      "sudo chown root:root ${local.kubelet_cert_path} ${local.kubelet_key_path}",
      "sudo chmod 0644 ${local.kubelet_cert_path}",
      "sudo chmod 0600 ${local.kubelet_key_path}"
    ]
  }
}

resource "null_resource" "certificates" {
  depends_on = [
    # This dependency is actually not necessary. But it cleans the log a little
    # since the file provisioner does not log retries.
    null_resource.kubelet_certificate
  ]
  for_each = local.control_plane_nodes

  triggers = {
    cluster   = null_resource.cluster.id
    server_id = hcloud_server.servers[each.key].id
    role      = each.value.role

    kubernetes_ca  = sha1(var.ca_certificates.kubernetes.cert)
    etcd_ca        = sha1(var.ca_certificates.etcd.cert)
    front_proxy_ca = sha1(var.ca_certificates.front_proxy.cert)
    kubelet_ca     = sha1(var.ca_certificates.kubelet.cert)
    sa_keypair     = sha1(var.sa_keypair.public_key_pem)
  }

  connection {
    user        = coalesce(each.value.ssh_user, "kube")
    host        = hcloud_server.servers[each.key].ipv4_address
    private_key = var.ssh_key.private_key
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /tmp/pki /tmp/pki/etcd"]
  }

  provisioner "file" {
    content     = var.ca_certificates.kubernetes.cert
    destination = "/tmp/pki/ca.crt"
  }

  provisioner "file" {
    content     = var.ca_certificates.kubernetes.key
    destination = "/tmp/pki/ca.key"
  }

  provisioner "file" {
    content     = var.ca_certificates.etcd.cert
    destination = "/tmp/pki/etcd/ca.crt"
  }

  provisioner "file" {
    content     = var.ca_certificates.etcd.key
    destination = "/tmp/pki/etcd/ca.key"
  }

  provisioner "file" {
    content     = var.ca_certificates.front_proxy.cert
    destination = "/tmp/pki/front-proxy-ca.crt"
  }

  provisioner "file" {
    content     = var.ca_certificates.front_proxy.key
    destination = "/tmp/pki/front-proxy-ca.key"
  }

  provisioner "file" {
    content     = var.ca_certificates.kubelet.cert
    destination = "/tmp/pki/kubelet-ca.crt"
  }

  provisioner "file" {
    content     = var.sa_keypair.public_key_pem
    destination = "/tmp/pki/sa.pub"
  }

  provisioner "file" {
    content     = var.sa_keypair.private_key_pem
    destination = "/tmp/pki/sa.key"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${local.cert_dir}/",
      "sudo mv /tmp/pki/* ${local.cert_dir}/",
      "sudo rm -rf /tmp/pki/",
      "sudo chown root:root ${local.cert_dir}",
      "sudo find ${local.cert_dir} -type f -name '*.crt' -exec sudo chmod 644 {} \\;",
      "sudo find ${local.cert_dir} -type f -name '*.key' -exec sudo chmod 600 {} \\;"
    ]
  }
}
