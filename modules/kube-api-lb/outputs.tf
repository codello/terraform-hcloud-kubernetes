output "id" {
  value       = hcloud_load_balancer.this.id
  description = "The ID of the load balancer."
}

output "public_ipv4" {
  value       = hcloud_load_balancer.this.ipv4
  description = "The public IPv4 address of the API load balancer."
}

output "public_ipv6" {
  value       = hcloud_load_balancer.this.ipv6
  description = "The public IPv6 address of the API load balancer."
}

output "private_ipv4" {
  value       = try(hcloud_load_balancer_network.network.ip, null)
  description = "The private IPv4 address of the API load balancer. Only available if networks are enabled."
}
