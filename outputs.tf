output "id" {
  description = "The ID of teh cluster."
  value       = module.cluster.id
}

output "node_info" {
  description = "Information about the cluster's nodes."
  value       = module.cluster.node_info
}

output "leader" {
  description = "The name of the leader node."
  value       = module.cluster.leader
}

output "ipv4_address" {
  description = "The IP address of the API server or its load balancer."
  value       = local.ha_mode ? module.api_lb[0].public_ipv4 : module.cluster.node_info[module.cluster.leader].public_ipv4
}

output "ipv6_address" {
  description = "The IPv6 address of the API server or its load balancer."
  value       = local.ha_mode ? module.api_lb[0].public_ipv6 : module.cluster.node_info[module.cluster.leader].public_ipv6
}

output "endpoint" {
  description = "The stable control plane endpoint."
  value       = local.endpoint
}

output "ca_certificate" {
  description = "The certificate of the cluster CA (for convenience)."
  value       = module.cluster.ca_certificate
}

output "admin_kubeconfig" {
	description = "A kubeconfig for the cluster administrator."
	value		    = module.admin_user.kubeconfig
  sensitive   = true
}
