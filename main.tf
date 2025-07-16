### Main TF file
##  others are called were needed


# Configure the OpenStack Provider for Telekom Cloud




# Get current region and project info
data "opentelekomcloud_identity_project_v3" "current" {}

# Simple approach - discover resources without complex for_each loops
# VPC data source (single VPC query - you may need to specify filters)
data "opentelekomcloud_vpc_v1" "default" {
  # You can add filters here if needed
  # name = "default"
}

# Subnet data source (single subnet query - you may need to specify VPC ID)
data "opentelekomcloud_vpc_subnet_v1" "default" {
  # vpc_id = data.opentelekomcloud_vpc_v1.default.id
}

# Compute instances data source  
data "opentelekomcloud_compute_instances_v2" "all" {}

# Security Groups
data "opentelekomcloud_networking_secgroup_v2" "all" {}

# Available flavors
data "opentelekomcloud_compute_flavors_v2" "all" {}

# Available images
data "opentelekomcloud_images_image_v2" "latest" {
  most_recent = true
}

# Key pairs
data "opentelekomcloud_compute_keypairs_v2" "all" {}

# RDS instances
data "opentelekomcloud_rds_instances_v3" "all" {}

# ELB load balancers
data "opentelekomcloud_lb_loadbalancers_v2" "all" {}

# CCE clusters
data "opentelekomcloud_cce_clusters_v3" "all" {}

# DNS zones
data "opentelekomcloud_dns_zones_v2" "all" {}

# Object Storage buckets
data "opentelekomcloud_obs_buckets" "all" {}

# DCS Redis instances
data "opentelekomcloud_dcs_instances_v1" "all" {}

# ECS instances data source (alternative to compute_instances)
data "opentelekomcloud_ecs_instances_v1" "all" {}

# Networking data sources
data "opentelekomcloud_networking_network_v2" "all" {}

# VPC peering connections
data "opentelekomcloud_vpc_peering_connections_v2" "all" {}

# EIP data source
data "opentelekomcloud_vpc_eips_v1" "all" {}

# Local values for easier reference
locals {
  # Extract data from data sources safely
  compute_instances = try(data.opentelekomcloud_compute_instances_v2.all.instances, [])
  ecs_instances     = try(data.opentelekomcloud_ecs_instances_v1.all.instances, [])
  security_groups   = try(data.opentelekomcloud_networking_secgroup_v2.all.security_groups, [])
  rds_instances     = try(data.opentelekomcloud_rds_instances_v3.all.instances, [])
  loadbalancers     = try(data.opentelekomcloud_lb_loadbalancers_v2.all.loadbalancers, [])
  cce_clusters      = try(data.opentelekomcloud_cce_clusters_v3.all.clusters, [])
  dns_zones         = try(data.opentelekomcloud_dns_zones_v2.all.zones, [])
  obs_buckets       = try(data.opentelekomcloud_obs_buckets.all.buckets, [])
  dcs_instances     = try(data.opentelekomcloud_dcs_instances_v1.all.instances, [])
  networks          = try(data.opentelekomcloud_networking_network_v2.all.networks, [])
  peering_connections = try(data.opentelekomcloud_vpc_peering_connections_v2.all.peering_connections, [])
  eips              = try(data.opentelekomcloud_vpc_eips_v1.all.eips, [])
  
  # Project information
  project_id   = data.opentelekomcloud_identity_project_v3.current.id
  project_name = data.opentelekomcloud_identity_project_v3.current.name
}