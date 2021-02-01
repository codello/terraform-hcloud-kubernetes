# Kubernetes Cluster with Cloudflare DNS

This example creates a Kubernetes cluster on Hetzner Cloud using the `terraform-hcloud-kubernetes` module. It features
the following aspects:
- Multi-master HA configuration with a load-balanced API
- DNS via CloudFlare with integrated DNS propagation.
- Automatic kubeconfig generation so that the cluster is immediately usable.

## Using this module
1. Create a `*.auto.tfvars` file with the required variable values (see `variables.tf`).
2. Create an appropriate base image for the nodes (see the `packer` folder in this repo).
3. Run `terraform init`
4. Run `terraform apply`

## DNS Propagation
This example makes the cluster API available at a configurable DNS endpoint. It also configures a CloudFlare record to
point to the cluster. This example shows that cyclic dependencies do not occur and it shows how one can use
`bootstrap_dependencies` to make sure that the DNS records have properly propagated before the cluster is bootstrapped.
