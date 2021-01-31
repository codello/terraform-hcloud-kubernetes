# Hetzner Cloud Kubernetes Cluster
This repository contains a [Terraform](https://www.terraform.io/) module to create a kubernetes cluster on
[Hetzner Cloud](https://www.hetzner.com/cloud) using their cloud servers.

## How to use this module?
Have a look in the `examples` folder for some applications of this module. There are multiple examples available:
- `simple-cluster`: Creates a simple single-master cluster. This shows the minimal configuration.
- `cloudflare-ha-cluster`: A cluster with a highly available control plane.

## Module Structure
This module can be used as-is. It covers many typical situations. However if you need to implement a special usecase or
some of the assumptions made are not acceptable you can instead use the `modules/kube-cluster` submodule. It implements
the core of this module and also offers the greatest flexibility. You may want to use other submodules from the
`modules/` folder as well if convenient. Some typical applications for using the `kube-cluster` module directly might
be:
- Integrating a Kubernetes cluster into a complex network.
- Using existing PKI infrastructure
- Customizing preinstalled cluster addons

## Cluster Endpoints
One important concept you should understand are cluster endpoints. This module accepts a list of DNS names or IPs in
the `api_endpoints` variable. These (mostly the first one, we call this the primary endpoint) will be used in several
places:
- Configuring the cluster
- Signing API server certificates
- Generating kubeconfigs
Note that this module makes no effort in actually setting the DNS entries that you specify as cluster endpoints.

This module makes some effort to validate the cluster endpoints and to normalize the format. The module will only the
primary endpoint (the primary endpoint is exposed as an output variable as well). Here are some recommendations for
chosing endpoints:
- Choose stable DNS names or IPs. Changing the endpoints afterwards is not always possible.
- Do not use the IP of a node as primary endpoint. This will make it impossible to move the cluster to an HA
  configuration and will make your cluster unaccessible if that node goes down.
- The recommended approach is to use DNS names as cluster endpoints. This way you can dynamically change the value of
  the DNS record without affecting the cluster.
- Alternatively you might use the IP of a load balancer (this is not recommended as the cluster becomes inaccessible
  if the load balancer is removed).
- You could also use a floating IP address

## More Documentation
In order to get a better understanding of the benefits and caveats of this module you should read the
`modules/kube-cluster/README.md`. All of the documentation for that module also applies to this main module as it
merely implements some common defaults.
