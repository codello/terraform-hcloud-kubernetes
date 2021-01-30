resource "tls_private_key" "this" {
  algorithm   = var.algorithm
  rsa_bits    = var.rsa_bits
  ecdsa_curve = var.ecdsa_curve
}

resource "tls_self_signed_cert" "this" {
  key_algorithm   = tls_private_key.this.algorithm
  private_key_pem = tls_private_key.this.private_key_pem

  subject {
    common_name = var.common_name
  }
  
  validity_period_hours = var.validity_period_hours
  allowed_uses          = ["digital_signature", "key_encipherment", "cert_signing"]
  is_ca_certificate     = true
}
