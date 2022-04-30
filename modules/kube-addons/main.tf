locals {
  kubectl = "${path.module}/kubectl.sh"
  env = {
    KUBECTL     = var.kubectl_cmd
    ENDPOINT    = var.cluster_endpoint
    CA_CERT     = var.credentials.ca_cert
    CLIENT_CERT = var.credentials.client_cert
    CLIENT_KEY  = var.credentials.client_key
  }

  ccm_manifest = templatefile("${path.module}/manifests/hcloud-ccm.yaml", var.cloud_controller_manager)
  csi_manifest = templatefile("${path.module}/manifests/hcloud-csi-driver.yaml", defaults(var.csi_driver, {
    default_storage_class = true
    storage_class_name    = "hcloud-volumes"
  }))
  ssh_keys_manifest = templatefile("${path.module}/manifests/ssh-keys.yaml", {
    public_key  = base64encode(var.ssh_keys.public_key)
    private_key = base64encode(var.ssh_keys.private_key)
  })
  calico_manifest = templatefile("${path.module}/manifests/calico.yaml", defaults(var.calico, {
    ipam          = "host-local"
    overlay       = "none"
    force_overlay = false
  }))
  calico_manifest_docs = compact(split("---", local.calico_manifest))
  flannel_manifest     = templatefile("${path.module}/manifests/flannel.yaml", var.flannel)
}

# ---------------------------------------------------------------------------------------------------------------------
# SSH KEYS
# ---------------------------------------------------------------------------------------------------------------------
resource "null_resource" "ssh_keys" {
  count = var.ssh_keys.enabled ? 1 : 0
  triggers = {
    cluster  = var.cluster_id
    manifest = sha1(local.ssh_keys_manifest)
  }

  provisioner "local-exec" {
    command = "${local.kubectl} apply -f -"
    environment = merge(local.env, {
      STDIN = local.ssh_keys_manifest
    })
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CALICO
# ---------------------------------------------------------------------------------------------------------------------
resource "null_resource" "calico" {
  count = var.calico.enabled ? 1 : 0

  triggers = {
    cluster  = var.cluster_id
    manifest = sha1(local.calico_manifest)
  }

  provisioner "local-exec" {
    command     = "${local.kubectl} apply -f -"
    environment = merge(local.env, zipmap([for i in range(length(local.calico_manifest_docs)) : "STDIN${i}"], local.calico_manifest_docs))
  }

  # We want to wait for the calico pods to start up before deploying the CCM.
  # The reason is that otherwise some pods (such as CoreDNS) might get wrong IP
  # addresses because Calico IPAM has not started up yet.
  provisioner "local-exec" {
    command     = "${local.kubectl} wait -n kube-system --for=condition=READY pods --timeout=3m --selector=k8s-app=calico-node"
    environment = local.env
  }

  # TODO: Destroy-time Provisioner
}

# ---------------------------------------------------------------------------------------------------------------------
# FLANNEL
# ---------------------------------------------------------------------------------------------------------------------
resource "null_resource" "flannel" {
  count = var.flannel.enabled ? 1 : 0

  triggers = {
    cluster  = var.cluster_id
    manifest = sha1(local.flannel_manifest)
  }

  provisioner "local-exec" {
    command = "${local.kubectl} apply -f -"
    environment = merge(local.env, {
      STDIN = local.flannel_manifest
    })
  }

  # We want to wait for the calico pods to start up before deploying the CCM.
  # The reason is that otherwise some pods (such as CoreDNS) might get wrong IP
  # addresses because Calico IPAM has not started up yet.
  provisioner "local-exec" {
    command     = "${local.kubectl} wait -n kube-system --for=condition=READY pods --timeout=3m --selector=app=flannel"
    environment = local.env
  }

  # TODO: Destroy-time Provisioner
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUD CONTROLLER MANAGER
# ---------------------------------------------------------------------------------------------------------------------
resource "null_resource" "ccm" {
  count      = var.cloud_controller_manager.enabled ? 1 : 0
  depends_on = [null_resource.calico, null_resource.flannel]

  triggers = {
    cluster  = var.cluster_id
    manifest = sha1(local.ccm_manifest)
  }

  provisioner "local-exec" {
    command = "${local.kubectl} apply -f -"
    environment = merge(local.env, {
      STDIN = local.ccm_manifest
    })
  }

  # TODO: Destroy-time Provisioner
}

# ---------------------------------------------------------------------------------------------------------------------
# CSI DRIVER
# ---------------------------------------------------------------------------------------------------------------------
resource "null_resource" "csi" {
  count      = var.csi_driver.enabled ? 1 : 0
  depends_on = [null_resource.calico, null_resource.flannel]

  triggers = {
    cluster  = var.cluster_id
    manifest = sha1(local.csi_manifest)
  }

  provisioner "local-exec" {
    command = "${local.kubectl} apply -f -"
    environment = merge(local.env, {
      STDIN = local.csi_manifest
    })
  }

  # TODO: Destroy-time Provisioner
}
