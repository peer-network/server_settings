

# Configure the OpenStack Provider for Telekom Cloud
provider "opentelekomcloud" {
  auth_url    = var.auth_url
  domain_name = var.domain_name
  tenant_name = var.tenant_name
  user_name   = var.user_name
  password    = var.password != null ? var.password : lookup(var.env_vars, "OTC_PASSWORD", "")
  region      = var.region
}


# # main.tf
# provider "opentelekomcloud" {
#   access_key  = var.access_key
#   secret_key  = var.secret_key
#   tenant_name = var.tenant_name
#   region      = var.region
# }

# Data sources to discover existing resources


data "opentelekomcloud_identity_project_v3" "current" {}

# VPC Data Sources
data "opentelekomcloud_vpc_v1" "all_vpcs" {}

# For each VPC, get its subnets
data "opentelekomcloud_vpc_subnet_v1" "all_subnets" {
  for_each = toset([for vpc in data.opentelekomcloud_vpc_v1.all_vpcs.vpcs : vpc.id])
  vpc_id   = each.value
}


data "opentelekomcloud_vpc_v1" "existing_vpcs" {}

data "opentelekomcloud_networking_subnet_v2" "existing_subnets" {
  count = length(data.opentelekomcloud_vpc_v1.existing_vpcs.vpcs)
}

data "opentelekomcloud_compute_instance_v2" "existing_instances" {}

data "opentelekomcloud_rds_instance_v3" "existing_rds" {}

# Compute instances
data "opentelekomcloud_compute_instances_v2" "all_instances" {}

# Security Groups
data "opentelekomcloud_networking_secgroup_v2" "all_secgroups" {}

# Available flavors
data "opentelekomcloud_compute_flavors_v2" "all_flavors" {}

# Available images
data "opentelekomcloud_images_image_v2" "all_images" {
  most_recent = true
}

# Key pairs
data "opentelekomcloud_compute_keypairs_v2" "all_keypairs" {}

# RDS instances (if any)
data "opentelekomcloud_rds_instances_v3" "all_rds" {}

# ELB load balancers
data "opentelekomcloud_lb_loadbalancers_v2" "all_loadbalancers" {}

# CCE clusters
data "opentelekomcloud_cce_clusters_v3" "all_cce" {}

# DNS zones
data "opentelekomcloud_dns_zones_v2" "all_dns_zones" {}

# Object Storage buckets
data "opentelekomcloud_obs_buckets" "all_buckets" {}

# DCS Redis instances
data "opentelekomcloud_dcs_instances_v1" "all_dcs" {}

# Local values for easier reference
locals {
  vpc_list      = data.opentelekomcloud_vpc_v1.all_vpcs.vpcs
  instance_list = data.opentelekomcloud_compute_instances_v2.all_instances.instances
  secgroup_list = data.opentelekomcloud_networking_secgroup_v2.all_secgroups.security_groups
  
  # Create a map of VPC ID to VPC details
  vpc_map = {
    for vpc in local.vpc_list :
    vpc.id => vpc
  }
  
  # Create a map of instance ID to instance details
  instance_map = {
    for instance in local.instance_list :
    instance.id => instance
  }
}


# Environment variables lookup
variable "env_vars" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

# Variables
variable "auth_url" {
  description = "OpenStack auth URL"
  type        = string
  default     = "https://iam.eu-de.otc.t-systems.com/v3"  # EU-DE region
}

# variable "domain_name" {
#   description = "OpenStack domain name"
#   type        = string
# }

# variable "tenant_name" {
#   description = "OpenStack tenant/project name"
#   type        = string
# }

# variable "user_name" {
#   description = "OpenStack username"
#   type        = string
# }

# variable "password" {
#   description = "OpenStack password"
#   type        = string
#   sensitive   = true
#   default     = null  # Will be populated from environment variable
# }

# variable "region" {
#   description = "OpenStack region"
#   type        = string
#   default     = "eu-de"
# }