############################
# Core lists (provider 1.36+)
############################

# All ECS
data "opentelekomcloud_compute_instances_v2" "all" {}

# All EVS volumes
data "opentelekomcloud_evs_volumes_v2" "all" {}

# All Ports (then hydrate each)
data "opentelekomcloud_networking_port_ids_v2" "all" {}
data "opentelekomcloud_networking_port_v2" "by_id" {
  for_each = toset(data.opentelekomcloud_networking_port_ids_v2.all.ids)
  port_id  = each.value
}

#############################################
# VPCs, EIPs, NATs, ELBs, CBR via RMS/Config
#############################################

# --- VPCs
data "opentelekomcloud_rms_advanced_query_v1" "vpcs" {
  expression = <<-SQL
    SELECT id, name
    FROM resources
    WHERE provider='vpc' AND type='vpcs'
  SQL
}

# --- EIPs
data "opentelekomcloud_rms_advanced_query_v1" "eips" {
  expression = <<-SQL
    SELECT id, name, properties.public_ip_address, properties.port_id
    FROM resources
    WHERE provider='vpc' AND type='publicips'
  SQL
}

# --- NAT Gateways
data "opentelekomcloud_rms_advanced_query_v1" "nats" {
  expression = <<-SQL
    SELECT id, name, properties.router_id, properties.internal_network_id
    FROM resources
    WHERE provider='nat' AND type='gateways'
  SQL
}

# NAT rules per gateway (hydrate)
data "opentelekomcloud_nat_snat_rules_v2" "snat" {
  for_each   = { for r in data.opentelekomcloud_rms_advanced_query_v1.nats.results : r.id => r }
  gateway_id = each.key
}
data "opentelekomcloud_nat_dnat_rules_v2" "dnat" {
  for_each   = { for r in data.opentelekomcloud_rms_advanced_query_v1.nats.results : r.id => r }
  gateway_id = each.key
}

data "opentelekomcloud_lb_loadbalancer_v3" "lb" {
  for_each = { for r in data.opentelekomcloud_rms_advanced_query_v1.elbs.results : r.id => r }
  id       = each.key
}

# --- CBR Vaults & Backups
data "opentelekomcloud_rms_advanced_query_v1" "cbr_vaults" {
  expression = <<-SQL
    SELECT id, name, properties.size, properties.used
    FROM resources
    WHERE provider='cbr' AND type='vaults'
  SQL
}
data "opentelekomcloud_rms_advanced_query_v1" "cbr_backups" {
  expression = <<-SQL
    SELECT id, name, properties.resource_id, properties.size, properties.status
    FROM resources
    WHERE provider='cbr' AND type='backups'
  SQL
}

# --- (Optional) CCE clusters (top-level container infra)
data "opentelekomcloud_cce_cluster_v3" "clusters" {}


# Dedicated ELB load balancers (list via RMS, then hydrate each)
data "opentelekomcloud_rms_advanced_query_v1" "elbs" {
  expression = <<-SQL
    SELECT id, name
    FROM resources
    WHERE provider='elb' AND type='loadbalancers'
  SQL
}

# Subnet IDs for each VPC
data "opentelekomcloud_vpc_subnet_ids_v1" "by_vpc" {
  for_each = { for v in data.opentelekomcloud_rms_advanced_query_v1.vpcs.results : v.id => v }
  vpc_id   = each.key
}

# Hydrate every subnet
data "opentelekomcloud_vpc_subnet_v1" "subnet" {
  for_each = toset(flatten([for x in data.opentelekomcloud_vpc_subnet_ids_v1.by_vpc : x.ids]))
  id       = each.value
}
