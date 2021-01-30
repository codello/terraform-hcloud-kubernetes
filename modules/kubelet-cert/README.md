# Kubelet Certificate
This folder contains a [Terraform](https://www.terraform.io/) module that generates a x509 certificate for a kubelet.
This module basically encapsulates some defaults for the `tls` provider.

## How to use this module?
```terraform
module "kubelet_ca" {
  source   = "github.com/codello/terraform-hcloud-kubernetes//modules/kube-ca?ref=v0.1.0"

  algorithm   = "ECDSA"
  common_name = "kubelet"
}

module "kubelet_certs" {
  source   = "github.com/codello/terraform-hcloud-kubernetes//modules/kubelet-cert?ref=v0.1.0"

  kubelet_ca = module.kubelet_ca
  algorithm  = "ECDSA"
  names      = ["worker01"]
  ips        = ["10.0.0.10"]
}

```
This module is used by the default configurations of the `terraform-hcloud-kubernetes` module. Usually you do not need
to use this module yourself.

## Sensitive Data
This module creates the certificate using the `tls` provider so any private keys will be present in the state file. If
this is not acceptable you have to generate certificates using other means (e.g. Vault).
