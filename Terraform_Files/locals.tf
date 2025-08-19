############################################
# LOCALS: safe access, shaping, final object
############################################

# Safe pull of RMS results (works even when data blocks have count=0)
locals {
  rms_vpcs_results = try(data.opentelekomcloud_rms_advanced_query_v1.vpcs[0].results, [])
  rms_elbs_results = try(data.opentelekomcloud_rms_advanced_query_v1.elbs[0].results, [])
  rms_nats_results = try(data.opentelekomcloud_rms_advanced_query_v1.nats[0].results, [])

  # Prefer RMS VPC IDs if present, else use provided var.vpc_ids
  vpc_ids_effective = length(local.rms_vpcs_results) > 0
    ? [for v in local.rms_vpcs_results : v.id]
    : var.vpc_ids

  # IDs/maps used to drive guarded hydrations
  nat_ids = [for n in local.rms_nats_results : n.id]
  elb_map = { for r in local.rms_elbs_results : r.id => r }
}

# Normalize core resources (OTC direct + discovered subnets)
locals {
  vpcs = length(local.rms_vpcs_results) > 0 ? {
    for r in local.rms_vpcs_results :
    r.id => { id = r.id, name = try(r.name, null) }
  } : {
    for vpc_id in var.vpc_ids :
    vpc_id => { id = vpc_id, name = null }
  }

  subnets = {
    for s in values(data.opentelekomcloud_vpc_subnet_v1.subnet) :
    s.id => {
      id     = s.id
      name   = s.name
      cidr   = s.cidr
      vpc_id = s.vpc_id
    }
  }

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

  ports = {
    for p in values(data.opentelekomcloud_networking_port_v2.by_id) :
    p.id => {
      id           = p.id
      name         = p.name
      device_id    = p.device_id
      device_owner = p.device_owner
      network_id   = p.network_id
      fixed_ips    = p.all_fixed_ips          # [{ ip_address, subnet_id }]
      sg_ids       = try(p.all_security_group_ids, [])
    }
  }

  # Reverse index: ports by instance/device id
  ports_by_device = {
    for device_id in toset([for p in local.ports : p.device_id]) :
    device_id => [for p in local.ports : p if p.device_id == device_id]
  }

  # Volumes grouped per instance (attachment.server_id)
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
      }
      if length([for a in v.attachments : a if a.server_id == iid]) > 0
    ]
  }
}

# NATs / ELBs (empty when RMS is off)
locals {
  nats = [
    for n in local.rms_nats_results : {
      id   = n.id
      name = try(n.name, null)
      snat = try(data.opentelekomcloud_nat_snat_rules_v2.snat[n.id].rules, [])
      dnat = try(data.opentelekomcloud_nat_dnat_rules_v2.dnat[n.id].rules, [])
    }
  ]

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
}

# VMs grouped under each subnet, including NICs and volumes
locals {
  vms_by_subnet = {
    for sid, _ in local.subnets :
    sid => [
      for iid, inst in local.instances : merge(inst, {
        nics = [
          for port in lookup(local.ports_by_device, iid, []) : {
            port_id    = port.id
            ips        = port.fixed_ips    # list of { ip_address, subnet_id }
            sg_ids     = port.sg_ids
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
}

# Final nested object ready for export
locals {
  peer_network = {
    Peer_Network = {
      vpcs = [
        for vpc_id, v in local.vpcs : {
          id      = v.id
          label   = v.name
          subnets = [
            for s in [for x in values(local.subnets) : x if x.vpc_id == vpc_id] : {
              id         = s.id
              label      = s.name
              cidr       = s.cidr
              vms        = lookup(local.vms_by_subnet, s.id, [])
              containers = []
            }
          ]
        }
      ]
      nats           = local.nats
      load_balancers = local.elbs
      backups        = {}   # add guarded CBR later if you want
    }
  }
}
