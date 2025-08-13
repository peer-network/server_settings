locals {
  ecs     = data.opentelekomcloud_compute_instances_v2.all.instances
  evs     = data.opentelekomcloud_evs_volumes_v2.all.volumes
  subnets = [for s in values(data.opentelekomcloud_vpc_subnet_v1.subnet) : s]
  ports   = [for p in values(data.opentelekomcloud_networking_port_v2.port) : p]
  payload = {
    generated_at = timestamp()
    region       = var.region
    ecs          = local.ecs
    evs          = local.evs
    subnets      = local.subnets
    ports        = local.ports
  }
}

resource "local_file" "otc_inventory" {
  filename = "otc-inventory.json"
  content  = jsonencode(local.payload)
}
