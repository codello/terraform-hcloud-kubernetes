locals {
  kubelet_ca_enabled = length(var.kubelets) > 0
  cas                = toset(concat(["kubernetes", "etcd-ca", "front-proxy-ca"], local.kubelet_ca_enabled ? ["kubelet-ca"] : []))
}

# ---------------------------------------------------------------------------------------------------------------------
# SERVICE ACCOUNT KEYPAIR
# For some reason a ECDSA keypair does not work for service accounts.
# ---------------------------------------------------------------------------------------------------------------------
resource "tls_private_key" "sa_keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ---------------------------------------------------------------------------------------------------------------------
# CERTIFICATE AUTHORITIES
# The kubelet CA is only created if at least one kubelet has been specified.
# ---------------------------------------------------------------------------------------------------------------------
resource "tls_private_key" "cas" {
  for_each = local.cas

  algorithm   = var.algorithm
  rsa_bits    = var.rsa_bits
  ecdsa_curve = var.ecdsa_curve
}

resource "tls_self_signed_cert" "cas" {
  for_each = local.cas

  key_algorithm   = tls_private_key.cas[each.key].algorithm
  private_key_pem = tls_private_key.cas[each.key].private_key_pem

  subject {
    common_name = each.key
  }

  validity_period_hours = var.ca_validity_period_hours
  allowed_uses          = ["digital_signature", "key_encipherment", "cert_signing"]
  is_ca_certificate     = true
}

# ---------------------------------------------------------------------------------------------------------------------
# KUBELETS
# Each kubelet gets its own key.
# ---------------------------------------------------------------------------------------------------------------------
resource "tls_private_key" "kubelets" {
  for_each = var.kubelets

  algorithm   = var.algorithm
  ecdsa_curve = var.ecdsa_curve
  rsa_bits    = var.rsa_bits
}

resource "tls_cert_request" "kubelets" {
  for_each = var.kubelets

  key_algorithm   = tls_private_key.kubelets[each.key].algorithm
  private_key_pem = tls_private_key.kubelets[each.key].private_key_pem

  ip_addresses = each.value.ips
  dns_names    = concat([each.key], coalesce(each.value.names, []))

  subject {
    common_name = each.key
  }
}

resource "tls_locally_signed_cert" "kubelets" {
  for_each = var.kubelets

  cert_request_pem   = tls_cert_request.kubelets[each.key].cert_request_pem
  ca_key_algorithm   = tls_self_signed_cert.cas["kubelet-ca"].key_algorithm
  ca_cert_pem        = tls_self_signed_cert.cas["kubelet-ca"].cert_pem
  ca_private_key_pem = tls_private_key.cas["kubelet-ca"].private_key_pem

  validity_period_hours = var.kubelet_validity_period_hours

  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]
}
