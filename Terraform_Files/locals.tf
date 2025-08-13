# locals.tf (same dir as export.tf)

locals {
  ecs_raw     = data.opentelekomcloud_compute_instances_v2.all.instances
  evs_raw     = data.opentelekomcloud_evs_volumes_v2.all.volumes
  subnets_raw = [for s in values(data.opentelekomcloud_vpc_subnet_v1.subnet) : s]
  ports_raw   = [for p in values(data.opentelekomcloud_networking_port_v2.port) : p]

  ecs = [
    for s in local.ecs_raw : {
      id        = s.id
      name      = s.name
      status    = s.status
      az        = s.availability_zone
      flavor_id = s.flavor_id
      networks  = s.network
      secgroups = s.security_groups_ids
    }
  ]

  evs = [
    for v in local.evs_raw : {
      id     = v.id
      name   = v.name
      sizeGB = v.size
      az     = v.availability_zone
      status = v.status
      type   = v.volume_type
      attach = v.attachments
    }
  ]

  subnets = [
    for s in local.subnets_raw : {
      id     = s.id
      name   = s.name
      cidr   = s.cidr
      vpc_id = s.vpc_id
    }
  ]

  ports = [
    for p in local.ports_raw : {
      id           = p.id
      name         = p.name
      device_id    = p.device_id
      device_owner = p.device_owner
      network_id   = p.network_id
      fixed_ips    = p.all_fixed_ips
    }
  ]

  payload = {
    generated_at = timestamp()
    region       = var.region
    ecs          = local.ecs
    evs          = local.evs
    subnets      = local.subnets
    ports        = local.ports
  }
}
