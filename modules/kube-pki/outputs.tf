output "sa_keypair" {
  description = "The service account keypair."
  value = tls_private_key.sa_keypair
}

output "ca_certificates" {
  description = "The generated CA certificates."
  value       = merge(
    {
      kubernetes = {
        algorithm = tls_self_signed_cert.cas["kubernetes"].key_algorithm
        cert      = tls_self_signed_cert.cas["kubernetes"].cert_pem
        key       = tls_private_key.cas["kubernetes"].private_key_pem
      }
      etcd = {
        algorithm = tls_self_signed_cert.cas["etcd-ca"].key_algorithm
        cert      = tls_self_signed_cert.cas["etcd-ca"].cert_pem
        key       = tls_private_key.cas["etcd-ca"].private_key_pem
      }
      front_proxy = {
        algorithm = tls_self_signed_cert.cas["front-proxy-ca"].key_algorithm
        cert      = tls_self_signed_cert.cas["front-proxy-ca"].cert_pem
        key       = tls_private_key.cas["front-proxy-ca"].private_key_pem
      }
    },
    local.kubelet_ca_enabled ? {
      kubelet = {
        algorithm = tls_self_signed_cert.cas["kubelet-ca"].key_algorithm
        cert      = tls_self_signed_cert.cas["kubelet-ca"].cert_pem
        key       = tls_private_key.cas["kubelet-ca"].private_key_pem
      }
    } : {}
  )
}

output "kubelet_certs" {
  description = "The certificates for the individual kubelets."
  value       = {
    for name,config in var.kubelets : name => {
      cert = tls_locally_signed_cert.kubelets[name].cert_pem
      key  = tls_private_key.kubelets[name].private_key_pem
    }
  }
}
