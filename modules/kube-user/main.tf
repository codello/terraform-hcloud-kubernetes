locals {
  private_key_pem = coalesce(var.private_key_pem, tls_private_key.key[0].private_key_pem)
  context_name    = var.context_name != null ? var.context_name : "${var.username}@${var.cluster_name}"
  # See: https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
  kubeconfig      = {
    apiVersion      = "v1"
    kind            = "Config"
    preferences     = {}
    current-context = local.context_name

    clusters = [{
      name = var.cluster_name
      cluster = {
        server                     = var.cluster_endpoint
        certificate-authority-data = base64encode(var.kubernetes_ca.cert)
      }
    }]
    users = [{
      name = var.username
      user = {
        client-certificate-data = base64encode(tls_locally_signed_cert.cert.cert_pem)
        client-key-data         = base64encode(local.private_key_pem)
      }
    }]
    contexts = [{
      name = local.context_name
      context = {
        user    = var.username
        cluster = var.cluster_name
      }
    }]
  }
}

resource "tls_private_key" "key" {
  count = var.private_key_pem != null ? 0 : 1

  algorithm   = var.algorithm
  rsa_bits    = var.rsa_bits
  ecdsa_curve = var.ecdsa_curve
}

resource "tls_cert_request" "request" {
  key_algorithm   = var.algorithm
  private_key_pem = local.private_key_pem
  
  subject {
    common_name  = var.username
    organization = var.groups
  }
}

resource "tls_locally_signed_cert" "cert" {
  cert_request_pem   = tls_cert_request.request.cert_request_pem
  ca_key_algorithm   = var.kubernetes_ca.algorithm
  ca_cert_pem        = var.kubernetes_ca.cert
  ca_private_key_pem = var.kubernetes_ca.key
  
  validity_period_hours = var.validity_period_hours
  
  allowed_uses = ["digital_signature", "key_encipherment"]
}
