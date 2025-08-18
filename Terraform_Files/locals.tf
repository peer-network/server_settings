# locals.tf 

# VPCs map
locals {
  vpcs = {
    for r in local.vpcs_results :
    r.id => { id = r.id, name = try(r.name, try(r.properties.name, null), null) }
  }

  # Subnets map
  subnets = {
    for s in values(data.opentelekomcloud_vpc_subnet_v1.subnet) :
    s.id => { id = s.id, name = s.name, cidr = s.cidr, vpc_id = s.vpc_id }
  }

  # Instances map
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

  # Ports map
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

  # Reverse index: ports by device (instance) id
  ports_by_device = {
    for device_id in toset([for p in local.ports : p.device_id]) :
    device_id => [for p in local.ports : p if p.device_id == device_id]
  }

  # EIPs keyed by portId (guarded RMS)
  eips_results = (length(data.opentelekomcloud_rms_advanced_query_v1.eips) > 0
  ? data.opentelekomcloud_rms_advanced_query_v1.eips[0].results : [])
  eip_by_port = {
    for r in local.eips_results :
    try(r.properties.portId, null) => {
      eip_id = r.id
      eip    = try(r.properties.publicIpAddress, null)
      name   = try(r.name, null)
    }
    if try(r.properties.portId, null) != null
  }

  # Volumes per instance
  vols_by_instance = {
    for iid in keys(local.instances) :
    iid => [
      for v in data.opentelekomcloud_evs_volumes_v2.all.volumes :
      {
        id     = v.id
        name   = v.name
        sizeGB = v.size
        status = v.status
        type   = v.volume_type
      } if length([for a in v.attachments : a if a.server_id == iid]) > 0
    ]
  }

  # Security group IDs (to resolve names)
  all_sg_ids = toset(flatten([for _, inst in local.instances : inst.sgs]))
}

# SG name resolver
data "opentelekomcloud_networking_secgroup_v2" "sg" {
  for_each    = local.all_sg_ids
  secgroup_id = each.value
}

# Group subnets under VPCs
locals {
  subnets_by_vpc = {
    for vpc_id in keys(local.vpcs) :
    vpc_id => [for s in values(local.subnets) : s if s.vpc_id == vpc_id]
  }

  # VMs under each subnet (with NICs/EIPs/SG names/Volumes)
  vms_by_subnet = {
    for sid, _ in local.subnets :
    sid => [
      for iid, inst in local.instances : merge(inst, {
        nics = [
          for port in lookup(local.ports_by_device, iid, []) : {
            port_id  = port.id
            ips      = port.fixed_ips
            eip      = lookup(local.eip_by_port, port.id, null)
            sg_ids   = port.sg_ids
            sg_names = [for sgid in port.sg_ids : try(data.opentelekomcloud_networking_secgroup_v2.sg[sgid].name, sgid)]
          }
          if length([for ip in port.fixed_ips : ip if ip.subnet_id == sid]) > 0
        ]
        volumes = lookup(local.vols_by_instance, iid, [])
      })
      if length([
        for port in lookup(local.ports_by_device, iid, []) :
        1 if length([for ip in port.fixed_ips : ip if ip.subnet_id == sid]) > 0
      ]) > 0
    ]
  }

  # NATs with rules (guarded)
  nats_results = (length(data.opentelekomcloud_rms_advanced_query_v1.nats) > 0
  ? data.opentelekomcloud_rms_advanced_query_v1.nats[0].results : [])
  nats = [
    for n in local.nats_results : {
      id   = n.id
      name = try(n.name, null)
      snat = try(data.opentelekomcloud_nat_snat_rules_v2.snat[n.id].rules, [])
      dnat = try(data.opentelekomcloud_nat_dnat_rules_v2.dnat[n.id].rules, [])
    }
  ]

  elb_map = (
    var.enable_rms && length(data.opentelekomcloud_rms_advanced_query_v1.elbs) > 0
    ? { for r in data.opentelekomcloud_rms_advanced_query_v1.elbs[0].results : r.id => r }
    : {}
  )

  # ELBs (guarded)
  elbs = [
    for id, lb in data.opentelekomcloud_lb_loadbalancer_v3.lb : {
      id          = id
      name        = null
      vip_address = lb.vip_address
      router_id   = lb.router_id
      network_ids = lb.network_ids
      azs         = lb.availability_zones
    }
  ]

  # CBR (guarded)
  cbr_vaults = (length(data.opentelekomcloud_rms_advanced_query_v1.cbr_vaults) > 0
  ? data.opentelekomcloud_rms_advanced_query_v1.cbr_vaults[0].results : [])
  cbr_backups = (length(data.opentelekomcloud_rms_advanced_query_v1.cbr_backups) > 0
  ? data.opentelekomcloud_rms_advanced_query_v1.cbr_backups[0].results : [])
  backups = {
    vaults  = [for v in local.cbr_vaults : { id = v.id, name = v.name }]
    backups = [for b in local.cbr_backups : { id = b.id, name = b.name, resource_id = try(b.properties.resource_id, null), status = try(b.properties.status, null) }]
  }

  # Final nested object
  peer_network = {
    Peer_Network = {
      vpcs = [
        for vpc_id, v in local.vpcs : {
          id    = v.id
          label = v.name
          subnets = [
            for s in lookup(local.subnets_by_vpc, vpc_id, []) : {
              id         = s.id
              label      = s.name
              cidr       = s.cidr
              vms        = lookup(local.vms_by_subnet, s.id, [])
              containers = [] # fill via k8s provider if desired
            }
          ]
        }
      ]
      nats           = local.nats
      load_balancers = local.elbs
      backups        = local.backups
    }
  }
}
