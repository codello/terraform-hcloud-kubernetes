module "cluster" {
  source = "../../"

  name            = "kubernetes"
  cluster_version = "v1.19.6"
  location        = "nbg1"
  hcloud_token    = var.hcloud_k8s_token

  node_defaults = {
    server_type  = "cpx11"
    kubelet_args = { cgroup-driver = "systemd" }
  }

  nodes = {
    master = { role = "control-plane" }
    worker = {}
  }
}

# We store the kubeconfig at ~/.kube/config so the cluster is immediately usable. This is probably not something you
# want to do if you regularly work with multiple clusters.
resource "local_file" "kubeconfig" {
  sensitive_content = module.cluster.admin_kubeconfig.rendered
  filename          = pathexpand("~/.kube/config")
  file_permission   = "0600"
}
