# data_inventory.tf

# ECS instances (list)
data "opentelekomcloud_compute_instances_v2" "all" {}

# EVS volumes (list)
data "opentelekomcloud_evs_volumes_v2" "all" {}

# Subnets -> get IDs then hydrate details
data "opentelekomcloud_vpc_subnet_ids_v1" "all" {}
data "opentelekomcloud_vpc_subnet_v1" "subnet" {
  for_each = toset(data.opentelekomcloud_vpc_subnet_ids_v1.all.ids)
  id       = each.value
}

# Ports -> get IDs then hydrate details
data "opentelekomcloud_networking_port_ids_v2" "all" {}
data "opentelekomcloud_networking_port_v2" "port" {
  for_each = toset(data.opentelekomcloud_networking_port_ids_v2.all.ids)
  port_id  = each.value
}