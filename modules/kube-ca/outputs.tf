output "algorithm" {
  value       = tls_self_signed_cert.this.key_algorithm
  description = "The algorithm of the certificate."
}

output "cert" {
  value       = tls_self_signed_cert.this.cert_pem
  description = "The generated public certificate."
}

output "key" {
  value       = tls_private_key.this.private_key_pem
  description = "The CA private key."
  sensitive   = true
}
