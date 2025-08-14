locals {
  # Group subnets under VPCs
  subnets_by_vpc = {
    for vpc_id, v in local.vpcs :
    vpc_id => [
      for s in local.subnets :
      s.value if s.value.vpc_id == vpc_id
    ]
  }

  # For each subnet, pick VMs whose ports land in that subnet
  vms_by_subnet = {
    for sid, s in local.subnets :
    sid => [
      for inst_id, inst in local.instances : merge(inst, {
        nics = [
          for port in lookup(local.ports_by_device, inst_id, []) :
          {
            port_id   = port.id
            ips       = port.fixed_ips
            eip       = lookup(local.eip_by_port, port.id, null)
            sg_ids    = port.sg_ids
            sg_names  = [for sgid in port.sg_ids : try(data.opentelekomcloud_networking_secgroup_v2.sg[sgid].name, sgid)]
          }
          if length([for ip in port.fixed_ips : ip if ip.subnet_id == sid]) > 0
        ]
        volumes = lookup(local.vols_by_instance, inst_id, [])
      })
      if length([
        for port in lookup(local.ports_by_device, inst_id, []) :
        1 if length([for ip in port.fixed_ips : ip if ip.subnet_id == sid]) > 0
      ]) > 0
    ]
  }

  # NATs with child rules
  nats = [
    for n in data.opentelekomcloud_rms_advanced_query_v1.nats.results : {
      id        = n.id
      name      = try(n.name, null)
      router_id = try(n.properties.router_id, null)
      snat      = try(data.opentelekomcloud_nat_snat_rules_v2.snat[n.id].rules, [])
      dnat      = try(data.opentelekomcloud_nat_dnat_rules_v2.dnat[n.id].rules, [])
    }
  ]

  # ELBs with a few key fields
  elbs = [
    for id, lb in data.opentelekomcloud_lb_loadbalancer_v3.lb : {
      id           = id
      name         = try(data.opentelekomcloud_rms_advanced_query_v1.elbs.results[*].name[ index(data.opentelekomcloud_rms_advanced_query_v1.elbs.results[*].id, id) ], null)
      vip_address  = lb.vip_address
      router_id    = lb.router_id
      network_ids  = lb.network_ids
      azs          = lb.availability_zones
    }
  ]

  # CBR
  cbr = {
    vaults  = [for v in data.opentelekomcloud_rms_advanced_query_v1.cbr_vaults.results : { id = v.id, name = v.name, size = try(v.properties.size, null), used = try(v.properties.used, null) }]
    backups = [for b in data.opentelekomcloud_rms_advanced_query_v1.cbr_backups.results : { id = b.id, name = b.name, resource_id = try(b.properties.resource_id, null), size = try(b.properties.size, null), status = try(b.properties.status, null) }]
  }

  # CCE clusters (top-level)
  cce = {
    clusters = try(data.opentelekomcloud_cce_cluster_v3.clusters.clusters, [])
  }

  # Final payload as requested
  peer_network = {
    Peer_Network = {
      vpcs = [
        for vpc_id, v in local.vpcs : {
          id      = v.id
          label   = v.name
          subnets = [
            for s in lookup(local.subnets_by_vpc, vpc_id, []) : {
              id        = s.id
              label     = s.name
              cidr      = s.cidr
              vms       = lookup(local.vms_by_subnet, s.id, [])
              containers = [] # fill via Kubernetes provider if needed
            }
          ]
        }
      ]

      nats           = local.nats
      load_balancers = local.elbs
      backups        = local.cbr
      cce            = local.cce
    }
  }
}

# Write the YAML file
resource "local_sensitive_file" "peer_network_yaml" {
  filename        = "peer_network.yaml"
  content         = yamlencode(local.peer_network)
  file_permission = "0640"
}

output "peer_network_yaml_path" {
  value = local_sensitive_file.peer_network_yaml.filename
}
