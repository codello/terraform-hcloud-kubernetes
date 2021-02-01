# Basic Terraform Cluster

This example creates a Kubernetes cluster on Hetzner Cloud using the `terraform-hcloud-kubernetes` module. It shows one
of the most basic ways to create a cluster.

The created cluster features a single master and worker and does not offer HA for the control plane. In fact rotating
control plane nodes is not possible at all using this configuration (see the `cloudflare-ha-cluster` example for this
usecase).

## Using this module
1. Create a `*.auto.tfvars` file with the required variable values (see `variables.tf`).
2. Create an appropriate base image for the nodes (see the `packer` folder in this repo).
3. Run `terraform init`
4. Run `terraform apply`
