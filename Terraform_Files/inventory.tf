############################################
# INVENTORY: OTC direct + RMS (guarded)
# - Variables expected (define in variables.tf):
#   enable_rms (bool), vpc_ids (list(string)), port_sample_size (number)
############################################

############################
# Core OTC (non-RMS) lists
############################

# All ECS instances
data "opentelekomcloud_compute_instances_v2" "all" {}

# All EVS volumes
data "opentelekomcloud_evs_volumes_v2" "all" {}

# Ports: get IDs, then hydrate a bounded set to avoid API/provider overload
data "opentelekomcloud_networking_port_ids_v2" "all" {}

# Limit per run via var.port_sample_size (raise gradually if you have lots)
locals {
  all_port_ids       = data.opentelekomcloud_networking_port_ids_v2.all.ids
  port_ids_effective = length(local.all_port_ids) > var.port_sample_size
    ? slice(local.all_port_ids, 0, var.port_sample_size)
    : local.all_port_ids
}

data "opentelekomcloud_networking_port_v2" "by_id" {
  for_each = toset(local.port_ids_effective)
  port_id  = each.value
}

#############################################
# RMS (Config) queries — fully guarded
# Minimal SELECTs to avoid schema surprises.
#############################################

# VPCs (id, name)
data "opentelekomcloud_rms_advanced_query_v1" "vpcs" {
  count = var.enable_rms ? 1 : 0
  expression = <<-SQL
    SELECT id, name
    FROM resources
    WHERE provider='vpc' AND type='vpcs'
  SQL
}

# ELBs (id, name) -> then hydrate details below
data "opentelekomcloud_rms_advanced_query_v1" "elbs" {
  count = var.enable_rms ? 1 : 0
  expression = <<-SQL
    SELECT id, name
    FROM resources
    WHERE provider='elb' AND type='loadbalancers'
  SQL
}

# NAT Gateways (id, name) -> then hydrate rules below
data "opentelekomcloud_rms_advanced_query_v1" "nats" {
  count = var.enable_rms ? 1 : 0
  expression = <<-SQL
    SELECT id, name
    FROM resources
    WHERE provider='nat' AND type='natGateways'
  SQL
}

#############################################
# Subnets per VPC
# Uses local.vpc_ids_effective from locals.tf
#############################################

data "opentelekomcloud_vpc_subnet_ids_v1" "by_vpc" {
  for_each = toset(local.vpc_ids_effective)
  vpc_id   = each.value
}

data "opentelekomcloud_vpc_subnet_v1" "subnet" {
  for_each = toset(flatten([for x in data.opentelekomcloud_vpc_subnet_ids_v1.by_vpc : x.ids]))
  id       = each.value
}

#############################################
# NAT rules hydrate (only when RMS is ON)
#############################################

data "opentelekomcloud_nat_snat_rules_v2" "snat" {
  for_each   = var.enable_rms ? toset(local.nat_ids) : toset([])
  gateway_id = each.value
}

data "opentelekomcloud_nat_dnat_rules_v2" "dnat" {
  for_each   = var.enable_rms ? toset(local.nat_ids) : toset([])
  gateway_id = each.value
}

#############################################
# ELB detail hydrate (only when RMS is ON)
#############################################

data "opentelekomcloud_lb_loadbalancer_v3" "lb" {
  for_each = var.enable_rms ? local.elb_map : {}
  id       = each.key
}
