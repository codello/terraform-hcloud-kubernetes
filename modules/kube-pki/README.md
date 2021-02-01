# Kubernetes Certificate Authority
This folder contains a [Terraform](https://www.terraform.io/) module that generates certificate authorities and
certificates and key suitable to be deployed and used with `kubeadm`. This module basically encapsulates some defaults
for the `tls` provider. The module is used for two key aspects:
- Generating CA certificates for a kubernetes cluster
- Generating kubelet certificates for individual nodes

## How to use this module?
```terraform
module "pki" {
  source = "github.com/codello/terraform-hcloud-kubernetes//modules/kube-pki?ref=v0.1.0"

  algorithm = "ECDSA"
  rsa_bits  = 4096 # For the SA keypair

  kubelets = {
    "master" = { ips = ["1.2.3.4"] }
    "worker" = { ips = ["5.6.7.8"] }
  }
}
```
This module is used by the default configurations of the `terraform-hcloud-kubernetes` module. Usually you do not need
to use this module yourself.

## Kubenet Certificates
Kubelets usually create their own self signed certificates. While this is fine it opens an attack vector (see
https://kubernetes.io/docs/concepts/architecture/control-plane-node-communication/#apiserver-to-kubelet). This module
can generate certificates for kubelets as well if you specify the `kubelets` argument. If at least one kubelet is
provided a kubelet CA will be generated as well and included in the `ca_certificates` attribute.

## Sensitive Data
This module creates the certificate using the `tls` provider to generate private keys so they will be present in the
state file. If this is not acceptable you have to generate certificates by other means (e.g. Vault).
