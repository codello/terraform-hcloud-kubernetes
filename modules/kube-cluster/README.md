# Kubernetes Cluster
This folder contains a [Terraform](https://www.terraform.io/) module to create a kubernetes cluster on
[Hetzner Cloud](https://www.hetzner.com/cloud) using their cloud servers.

This is the core module of the `terraform-hcloud-kubernetes` module that contains the main functionality. However in
many cases it is more convenient to use the root module since it already offers a couple of configuration options.

## How to use this module?
The module creates a Kubernetes cluster using `kubeadm`. The cluster is bootstrapped and all nodes specified are
joined. This is a minimal example. See `variables.tf` for all configuration options.

```terraform
resource "hcloud_ssh_key" "ssh_key" {
  name       = "SSH Key"
  public_key = file("~/.ssh/id_rsa.pub")
}

module "cluster" {
  source = "github.com/codello/terraform-hcloud-kubernetes//modules/kube-cluster?ref=v0.1.0"

  name                    = "kubernetes"
  cluster_version         = "v1.19.6"

  ssh_key = {
    id          = hcloud_ssh_key.ssh_key.id
    private_key = file("~/.ssh/id_rsa")
  }
  
  nodes = {
    "node1" = {
      type     = "cpx31"
      location = "nbg1"
      role     = "control-plane"
    }
  }

  kubeconfig   = "..."
  sa_keypair   = "..."
  certificates = {
    kubernetes_ca  = "..."
    etcd_ca        = "..."
    front_proxy_ca = "..."
    kubelet_ca     = "..."
  }
}
```

## Node Requirements
This module does **not** configure nodes to be able to run Kubernetes. It merely initializes the cluster using
`kubeadm` but does not install `kubeadm`, `kubelet` or a container runtime. These have to be provided by the image you
are using. By default this module uses a rudimentary `cloud-init` template that configures the default user and SSH
access but does nothing special. So you have basically two ways to create nodes:
- Provide a `user-data` document for each node that installs the required packages on first boot.
- Create a custom image (e.g. using Packer) and provide its ID (or a selector to find the image) for the nodes. This is
  the recommended approach.

As a starting point you can use the packer template provided in this repository. It configures a CentOS 8 system with
`kubeadm`, `kubelet` and the `cri-o` container runtime.

## Cluster Upgrades
Cluster upgrades are supported, but not very well tested yet. To upgrade a cluster set the `cluster_version` to the new
version. All restrictions to upgrades in Kubernetes apply, but are not validated. That means that you must make sure
that you change the version number appropriately.

Similarly cluster downgrades are not supported. This behavior is enforced by kubeadm but not by the Terraform module.
Lowering the `cluster_version` might lead to a situation where the actual cluster version and the value of the variable
do not match.

When a cluster upgrade is applied only the cluster components will be upgraded. Neither the nodes nor `kubeadm` itself
will be updated automatically. The following workflow is recommended for cluster upgrades:

1. Update your base image for the nodes to include the newer versions of `kubeadm` and the `kubelet`. The cluster will
   continue to use the old version.
2. Upgrade the cluster by changing the `cluster_version`.
3. Recreate all nodes to make sure that they use the updated cluster components (you might combine this step with step
   1 except for the `leader`).

Only after all nodes use the same version a new cluster upgrade should be attempted. See
https://kubernetes.io/docs/setup/release/version-skew-policy/.

## Networking
The `kube-cluster` module is designed to work with Hetzner cloud networks. You can set the `network_id` or `subnet_id`
to the ID of a cloud network or subnet and all nodes will join that network. In order to make sure that cluster traffic
will be sent over the cloud network you should install the Hetzner Cloud Controller Manager (see `kube-addons` module).
Networks should work out of the box.

If you do not specify a `network_id` or `subnet_id` the nodes will communicate over the public internet. While this
will work it is not recommended.

Moving from a non-networked cluster to a networked cluster (or the other way round) should work but there may be issues
with the API server. The same applies when you try to change from one network or subnet to another. These issues should
be fixable by recreating all nodes in the cluster. Note that you might need to update your CCM deployment as well.

## High Availability
The `kube-cluster` module supports hight availability configurations. All nodes that have `role = "control-plane"` will
be the masters of the clusters. Each master will run its own `etcd` server and will be able to server API requests. In
order to successfully create a highly available cluster you need to provide  the following:

- At least one stable control plane endpoint (see `api_endpoints`). The endpoint must be routable to the `leader` when
  the cluster is bootstrapped (see [Bootstrap Considerations](#Bootsrap_Considerations)).
- A load balancer that balances API requests between the control plane nodes (see `kube-api-lb` module).

Joining additional control plane nodes or removing them should work automatically. Note that in some situations there
may be deadlocks when joining multiple control plane nodes at once.

External `etcd` clusters are currently not supported by this module.

## Certificates and Secrets
The `kube-cluster` module does not create secrets in the Terraform state. All sensitive values are accepted as
variables and will not be persisted in the state file. However note that the `terraform-hcloud-kubernetes` module
**does** persist secrets in the state. If you are trying to keep secrets out of your state files you can use solutions
such as Vault and integrate them using the `kube-cluster` module.

Note that the external CA feature of kubeadm is currently not supported. It is required that the private keys of the
CAs are stored on the control plane nodes.

## Bootstrapping Considerations
This module generally does not differentiate between different nodes. The one exception to this rule is the
bootstrapping and upgrading process. These have to be done on a single node before all other nodes can follow.
Typically this is managed transparently and automatically. However in certain situations it may be necessary to
manually specify which node should be used for bootstrapping or upgrading purposes. This can be done by setting the
`leader` variable to the name of the respective node. As a rule of thumb cluster upgrades should be done without
adding or removing nodes in the same `terraform apply` run.

One important consideration is that the bootstrapping process requires the cluster to be reachable via its
`api_endpoints` (technically only the first of the endpoints needs to be reachable). This gives way to issues related
to DNS propagation as well to circular dependency situations (where you need the node IPs of the cluster in order to
make the endpoint reachable). Usually one solves this via module dependencies. However in some situations this is not
possible. To solve this problem, the `kube-cluster` module has a variable `bootstrap_dependencies` that can be set to
a list of dependencies that need to exist before the cluster can be bootstrapped. This can be used to make sure that
DNS records have had time to propagate or to make sure that the endpoints are reachable. See the example
`cloudflare-ha-cluster` for an example.
