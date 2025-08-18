# Build a VPC map from the RMS query
locals {
  vpcs = {
    for r in data.opentelekomcloud_rms_advanced_query_v1.vpcs.results :
    r.id => {
      id    = r.id
      name  = try(r.name, try(r.properties.name, null), null)
    }
  }

  # You already defined `subnets` as a map keyed by subnet ID.
  # Group those subnets under each VPC for export.
  subnets_by_vpc = {
    for vpc_id in keys(local.vpcs) :
    vpc_id => [
      for s in values(local.subnets) : s
      if s.vpc_id == vpc_id
    ]
  }

  # Ports: data.opentelekomcloud_networking_port_v2.by_id is also a map
  ports = {
    for p in values(data.opentelekomcloud_networking_port_v2.by_id) :
    p.id => {
      id           = p.id
      name         = p.name
      device_id    = p.device_id
      device_owner = p.device_owner
      network_id   = p.network_id
      fixed_ips    = p.all_fixed_ips
      sg_ids       = try(p.all_security_group_ids, [])
    }
  }

  # Instances (this one was already fine: it's a list, not a map)
  instances = {
    for i in data.opentelekomcloud_compute_instances_v2.all.instances :
    i.id => {
      id     = i.id
      name   = i.name
      status = i.status
      az     = i.availability_zone
      sgs    = try(i.security_groups_ids, [])
    }
  }

  ports_by_device = {
    for device_id, group in {
      for pid, port in local.ports :
      port.device_id => [
        for pp in local.ports : pp if pp.device_id == port.device_id
      ]
    } : device_id => group
  }

  # EIP by port_id (from RMS)
  eip_by_port = {
    for r in data.opentelekomcloud_rms_advanced_query_v1.eips.results :
    try(r.properties.port_id, null) => {
      eip_id  = r.id
      eip     = try(r.properties.public_ip_address, null)
      name    = try(r.name, null)
    }
    if try(r.properties.port_id, null) != null
  }

  # Volumes by instance (attachment.server_id)
  vols_by_instance = {
    for i in keys(local.instances) :
    i => [
      for v in data.opentelekomcloud_evs_volumes_v2.all.volumes :
      {
        id     = v.id
        name   = v.name
        sizeGB = v.size
        status = v.status
        type   = v.volume_type
      }
      if length([for a in v.attachments : a if a.server_id == i]) > 0
    ]
  }

  # SG name lookup (unique set of SG IDs)
  all_sg_ids = toset(flatten([
    for iid, inst in local.instances : inst.sgs
  ]))
}

# Resolve SG names
data "opentelekomcloud_networking_secgroup_v2" "sg" {
  for_each     = local.all_sg_ids
  secgroup_id  = each.value
}
