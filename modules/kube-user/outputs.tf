output "client_cert" {
  value       = tls_locally_signed_cert.cert.cert_pem
  description = "The certificate generated for the user."
}

output "client_key" {
  value       = local.private_key_pem
  sensitive   = true
  description = "The private key generated for the user."
}

output "cluster_endpoint" {
  value       = var.cluster_endpoint
  description = "The cluster endpoint passed as input."
}

output "kubernetes_ca" {
  value       = var.kubernetes_ca
  description = "The kubernetes_ca passed as input"
}

output "kubeconfig" {
  description = "The generated kubeconfig data."
  sensitive   = true
  value = {
    cluster_name           = var.cluster_name
    cluster_endpoint       = var.cluster_endpoint
    cluster_ca_certificate = var.kubernetes_ca.cert
    username               = var.username
    client_certificate     = tls_locally_signed_cert.cert.cert_pem
    client_key             = local.private_key_pem

    # The rendered kubeconfig can be used by kubectl.
    rendered = yamlencode(local.kubeconfig)
  }
}

