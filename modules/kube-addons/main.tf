locals {
  kubectl = "${path.module}/kubectl.sh"

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
  flannel_manifest = templatefile("${path.module}/manifests/flannel.yaml", var.flannel)
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
    environment = {
      STDIN      = local.ssh_keys_manifest
      KUBECONFIG = var.kubeconfig
    }
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
    command = "${local.kubectl} apply -f -"
    environment = {
      STDIN      = local.calico_manifest
      KUBECONFIG = var.kubeconfig
    }
  }

  # We want to wait for the calico pods to start up before deploying the CCM.
  # The reason is that otherwise some pods (such as CoreDNS) might get wrong IP
  # addresses because Calico IPAM has not started up yet.
  provisioner "local-exec" {
    command = "${local.kubectl} wait -n kube-system --for=condition=READY pods --selector=k8s-app=calico-node"
    environment = {
      KUBECONFIG = var.kubeconfig
    }
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
    environment = {
      STDIN      = local.flannel_manifest
      KUBECONFIG = var.kubeconfig
    }
  }

  # We want to wait for the calico pods to start up before deploying the CCM.
  # The reason is that otherwise some pods (such as CoreDNS) might get wrong IP
  # addresses because Calico IPAM has not started up yet.
  provisioner "local-exec" {
    command = "${local.kubectl} wait -n kube-system --for=condition=READY pods --selector=app=flannel"
    environment = {
      KUBECONFIG = var.kubeconfig
    }
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
    environment = {
      STDIN      = local.ccm_manifest
      KUBECONFIG = var.kubeconfig
    }
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
    environment = {
      STDIN      = local.csi_manifest
      KUBECONFIG = var.kubeconfig
    }
  }

  # TODO: Destroy-time Provisioner
}
