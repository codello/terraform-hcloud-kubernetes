# Kubernetes Certificate Authority
This folder contains a [Terraform](https://www.terraform.io/) module that generates a certificate authority certificate
and key suitable to be deployed and used with `kubeadm`. This module basically encapsulates some defaults for the `tls`
provider.

## How to use this module?
```terraform
module "ca" {
  source   = "github.com/codello/terraform-hcloud-kubernetes//modules/kube-ca?ref=v0.1.0"

  algorithm   = "ECDSA"
  common_name = "kubernetes"
}
```
This module is used by the default configurations of the `terraform-hcloud-kubernetes` module. Usually you do not need
to use this module yourself.

## Sensitive Data
This module creates the certificate using the `tls` provider so any private keys will be present in the state file. If
this is not acceptable you have to generate certificates using other means (e.g. Vault).
