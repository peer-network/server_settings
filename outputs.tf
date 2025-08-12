# outputs.tf

locals {
  instances = [
    for s in data.opentelekomcloud_compute_instances_v2.all.instances : {
      id        = s.id
      name      = s.name
      status    = s.status
      az        = s.availability_zone
      flavor_id = s.flavor_id
      networks  = s.network
      secgroups = s.security_groups_ids
    }
  ]

  volumes = [
    for v in data.opentelekomcloud_evs_volumes_v2.all.volumes : {
      id     = v.id
      name   = v.name
      sizeGB = v.size
      az     = v.availability_zone
      status = v.status
      attach = v.attachments
      type   = v.volume_type
    }
  ]

  subnets = [
    for s in data.opentelekomcloud_vpc_subnet_v1.subnet : {
      id     = s.value.id
      name   = s.value.name
      cidr   = s.value.cidr
      vpc_id = s.value.vpc_id
    }
  ]

  ports = [
    for p in data.opentelekomcloud_networking_port_v2.port : {
      id          = p.value.id
      name        = p.value.name
      device_id   = p.value.device_id
      device_owner= p.value.device_owner
      network_id  = p.value.network_id
      fixed_ips   = p.value.all_fixed_ips
    }
  ]
}

output "inventory_json" {
  value     = jsonencode({ instances = local.instances, volumes = local.volumes, subnets = local.subnets, ports = local.ports })
  sensitive = true
}
