# ECS instances (list)
data "opentelekomcloud_compute_instances_v2" "all" {}

# EVS volumes (list)
data "opentelekomcloud_evs_volumes_v2" "all" {}


data "opentelekomcloud_vpc_subnet_ids_v1" "subnets" {
  for_each = toset(var.vpc_ids)
  vpc_id   = each.value
}


# Subnets -> get IDs then hydrate details
locals {
  all_subnet_ids = flatten([for d in data.opentelekomcloud_vpc_subnet_ids_v1.subnets : d.ids])
}


data "opentelekomcloud_vpc_subnet_v1" "subnet" {
  for_each = toset(local.all_subnet_ids)
  id       = each.value
}


# Ports -> get IDs then hydrate details
data "opentelekomcloud_networking_port_ids_v2" "all" {}
data "opentelekomcloud_networking_port_v2" "port" {
  for_each = toset(data.opentelekomcloud_networking_port_ids_v2.all.ids)
  port_id  = each.value
}