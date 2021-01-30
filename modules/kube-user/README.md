# Kubernetes User
This folder contains a [Terraform](https://www.terraform.io/) module to create a client certificate for a user of a
Kubernetes cluster.

## How to use this module?
In order to generate a kubeconfig you need to provide the certificate and key of the cluster CA. The module takes care
of the rest. You then can use the module's `kubeconfig` output for a structured representation of the relevant info and
`kubeconfig.rendered` for a YAML representation of the kubeconfig.

```terraform
module "admin" {
  source = "github.com/codello/terraform-hcloud-kubernetes//modules/kube-user?ref=v0.1.0"
  
  cluster_name     = "kubernetes"
  cluster_endpoint = "https://my.cluster.tld"
  kubernetes_ca    = {
    algorithm = "RSA"
    cert      = "..."
    key       = "..."
  }

  username = "kubernetes-admin"
  groups   = "system:masters"
}

resource "local_file" "kubeconfig" {
  sensitive_content = module.admin.kubeconfig.rendered
  filename          = pathexpand("~/.kube/config")
  file_permission   = "0600"
}
```

## Sensitive Data
This module creates the certificate using the `tls` provider so any private keys will be present in the state file. If
this is not acceptable you may provide your own `private_key_pem`. However in most circumstances it would be advisable
to create your own PKI infrastructure and sign the certificates without using the `kube-user` module.
