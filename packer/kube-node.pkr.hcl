source "hcloud" "kube-node" {
  token       = var.hcloud-token
  image       = "centos-8"
  location    = "nbg1"
  server_type = "cx11"
  server_name = "centos8-kubernetes"

  snapshot_name   = "Kubernetes Node"
  snapshot_labels = {
    os = "centos"
    os-version = "8"
    kubernetes = ""
    kubernetes-version = var.version
    build = formatdate("YYYY-MM-DD", timestamp())
  }
  ssh_username = "root"
}

build {
  sources = ["source.hcloud.kube-node"]
  provisioner "shell" {
    scripts = [
      "scripts/crio.sh",
      "scripts/kubernetes.sh"
    ]
    environment_vars = [
      "K8S_VERSION=${trimprefix(var.version, "v")}",
      "CRIO_VERSION=${var.crio-version != null ? var.crio-version : join(".", slice(split(".", trimprefix(var.version, "v")), 0, 2))}"
    ]
  }
}
