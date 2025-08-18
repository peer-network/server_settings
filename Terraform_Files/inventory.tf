############################
# Core lists (provider)
############################
data "opentelekomcloud_compute_instances_v2" "all" {}
data "opentelekomcloud_evs_volumes_v2"       "all" {}

# Ports: list IDs then hydrate each
data "opentelekomcloud_networking_port_ids_v2" "all" {}
data "opentelekomcloud_networking_port_v2" "by_id" {
  for_each = toset(data.opentelekomcloud_networking_port_ids_v2.all.ids)
  port_id  = each.value
}

#############################################
# RMS queries (guarded)
#############################################
# VPCs
data "opentelekomcloud_rms_advanced_query_v1" "vpcs" {
  count = var.enable_rms ? 1 : 0
  expression = <<-SQL
    SELECT id, name
    FROM resources
    WHERE provider='vpc' AND type='vpcs'
  SQL
}

# EIPs (camelCase in properties)
data "opentelekomcloud_rms_advanced_query_v1" "eips" {
  count = var.enable_rms ? 1 : 0
  expression = <<-SQL
    SELECT id, name, properties.publicIpAddress, properties.portId
    FROM resources
    WHERE provider='vpc' AND type='publicips'
  SQL
}

# NAT Gateways (type name matters)
data "opentelekomcloud_rms_advanced_query_v1" "nats" {
  count = var.enable_rms ? 1 : 0
  expression = <<-SQL
    SELECT id, name
    FROM resources
    WHERE provider='nat' AND type='natGateways'
  SQL
}

# ELBs
data "opentelekomcloud_rms_advanced_query_v1" "elbs" {
  count = var.enable_rms ? 1 : 0
  expression = <<-SQL
    SELECT id, name
    FROM resources
    WHERE provider='elb' AND type='loadbalancers'
  SQL
}

data "opentelekomcloud_lb_loadbalancer_v3" "lb" {
  for_each = local.elb_map
  id       = each.key
}

# CBR vaults/backups (keep fields minimal to avoid schema surprises)
data "opentelekomcloud_rms_advanced_query_v1" "cbr_vaults" {
  count = var.enable_rms ? 1 : 0
  expression = <<-SQL
    SELECT id, name
    FROM resources
    WHERE provider='cbr' AND type='vaults'
  SQL
}
data "opentelekomcloud_rms_advanced_query_v1" "cbr_backups" {
  count = var.enable_rms ? 1 : 0
  expression = <<-SQL
    SELECT id, name, properties.resource_id, properties.status
    FROM resources
    WHERE provider='cbr' AND type='backups'
  SQL
}

############################
# Subnets per VPC (RMS or fallback list)
############################
locals {
  vpcs_results = (length(data.opentelekomcloud_rms_advanced_query_v1.vpcs) > 0
    ? data.opentelekomcloud_rms_advanced_query_v1.vpcs[0].results : [])
  vpc_ids_effective = length(local.vpcs_results) > 0 ? [for v in local.vpcs_results : v.id] : var.vpc_ids
}

data "opentelekomcloud_vpc_subnet_ids_v1" "by_vpc" {
  for_each = toset(local.vpc_ids_effective)
  vpc_id   = each.value
}

data "opentelekomcloud_vpc_subnet_v1" "subnet" {
  for_each = toset(flatten([for x in data.opentelekomcloud_vpc_subnet_ids_v1.by_vpc : x.ids]))
  id       = each.value
}

############################
# NAT rules hydrated by gateway IDs (if any)
############################
locals {
  nat_ids = (length(data.opentelekomcloud_rms_advanced_query_v1.nats) > 0
    ? [for n in data.opentelekomcloud_rms_advanced_query_v1.nats[0].results : n.id] : [])
}

data "opentelekomcloud_nat_snat_rules_v2" "snat" {
  for_each   = toset(local.nat_ids)
  gateway_id = each.value
}
data "opentelekomcloud_nat_dnat_rules_v2" "dnat" {
  for_each   = toset(local.nat_ids)
  gateway_id = each.value
}
