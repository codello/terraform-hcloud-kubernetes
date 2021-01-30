# Kubernetes Addons
This folder contains a [Terraform](https://www.terraform.io/) module that installs certain applications inside a
Kubernetes cluster. This module does not aim to provide a diverse selection of addons. Instead this module aims to
install some *basics* that will be used in most installations. The goal is to be able to create a "managed" cluster
that can then be filled with applications by users.

## How to use this module?
This 

```terraform
module "addons" {
  source = "github.com/codello/terraform-hcloud-kubernetes//modules/kube-addons?ref=v0.1.0"

  cluster_id = "..."
  kubeconfig = module.admin.kubeconfig.rendered  # See the kube-user module

  csi_driver = {
    enabled = true
    token   = "..."
  }

  calico = {
    enabled = true
  }
}
```

## Available Addons
The following addons are currently available:
- Hetzner Cloud Controller Manager
- Hetzner CSI Driver
- SSH Keys inside the cluster
- Calico CNI plugin
- Flannel CNI plugin

See `variables.tf` for details.

## Using multiple addons
If you want to install multiple addons it is strongly recommended **not** to use this module multiple times but to
instead enable multiple addons in one single module. The reason for this is that the module respects some dependencies
between addons (e.g. the CNI plugin is installed before the CCM and CSI driver). These dependencies will get lost if
you use multiple modules for multiple addons.
