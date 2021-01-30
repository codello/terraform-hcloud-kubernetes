output "cert" {
  value       = tls_locally_signed_cert.cert.cert_pem
  description = "The signed kubelet certificate."
}

output "key" {
  value = tls_private_key.key.private_key_pem
  description = "The private key for the certificate."
}
