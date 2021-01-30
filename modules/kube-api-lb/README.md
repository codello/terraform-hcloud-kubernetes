# Kubernetes API Load Balancer
This folder contains a [Terraform](https://www.terraform.io/) module to create a load balancer in the
[Hetzner Cloud](https://www.hetzner.com/cloud) that is preconfigured to be used for a kubernetes API.

This module encapsulates defaults for the Kubernetes API. Unless this is your exact application you are probably better
off configuring a `hcloud_load_balancer` yourself instead of using this module. The same applies if a feature you
require is missing from this module.

## How to use this module?
The module creates a `hcloud_load_balancer` and configures it with a service for the kubernetes API as well as a label
selector for its targets.

```terraform
module "api_lb" {
  source = "github.com/codello/terraform-hcloud-kubernetes//modules/kube-api-lb?ref=v0.1.0"

  name          = "kubernetes-api"
  type          = "lb11"
  location      = "nbg1"

  control_plane_selector = "kubernetes,role=control-plane"
}
```

## Additional configuration
This module exposes the ID of the created load balancer via the `id` attribute. You can use the ID to for example add
additional targets to the load balancer.
