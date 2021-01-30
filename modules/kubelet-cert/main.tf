resource "tls_private_key" "key" {
  algorithm   = var.algorithm
  ecdsa_curve = var.ecdsa_curve
}

resource "tls_cert_request" "request" {
  key_algorithm   = tls_private_key.key.algorithm
  private_key_pem = tls_private_key.key.private_key_pem
  
  ip_addresses = var.ips
  dns_names    = var.names

  subject {
    common_name = var.names[0]
  }
}

resource "tls_locally_signed_cert" "cert" {
  cert_request_pem   = tls_cert_request.request.cert_request_pem
  ca_key_algorithm   = var.kubelet_ca.algorithm
  ca_cert_pem        = var.kubelet_ca.cert
  ca_private_key_pem = var.kubelet_ca.key
  
  validity_period_hours = var.validity_period_hours
  
  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]
}
