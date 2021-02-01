output "id" {
  description = "An ID representing the initialized cluster. If the cluster is recretaed the ID changes."
  value       = null_resource.cluster.id
}

# This value is just copied from the input. It is included here for convenience.
output "ca_certificate" {
	description = "The certificate of the cluster CA."
	value				= var.ca_certificates.kubernetes.cert
}

output "node_info" {
  description = "A map of node names to information about the nodes."
  value       = {
    for node,config in var.nodes : node => {
      id           = hcloud_server.servers[node].id
      role         = config.role
      public_ipv4  = hcloud_server.servers[node].ipv4_address
      public_ipv6  = hcloud_server.servers[node].ipv6_address
      cluster_ip   = local.network_enabled ? hcloud_server_network.network[node].ip : hcloud_server.servers[node].ipv4_address # The IP of the node in the cluster.
    }
  }
}

output "leader" {
  description = "The name of the leader node."
  value       = local.leader
}
