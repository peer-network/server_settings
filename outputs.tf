# outputs.tf - Comprehensive OTC outputs
output "account_info" {
  description = "Current OTC account information"
  value = {
    project_id   = data.opentelekomcloud_identity_project_v3.current.id
    project_name = data.opentelekomcloud_identity_project_v3.current.name
    region       = var.region
    tenant_name  = var.tenant_name
  }
}

output "vpc_summary" {
  description = "Summary of all VPCs"
  value = {
    count = length(local.vpc_list)
    vpcs = {
      for vpc in local.vpc_list :
      vpc.id => {
        name   = vpc.name
        cidr   = vpc.cidr
        status = vpc.status
      }
    }
  }
}

output "subnet_summary" {
  description = "Summary of all subnets"
  value = {
    for vpc_id, subnet_data in data.opentelekomcloud_vpc_subnet_v1.all_subnets :
    vpc_id => {
      vpc_name = local.vpc_map[vpc_id].name
      subnets = [
        for subnet in subnet_data.subnets :
        {
          id              = subnet.id
          name            = subnet.name
          cidr            = subnet.cidr
          gateway_ip      = subnet.gateway_ip
          availability_zone = subnet.availability_zone
        }
      ]
    }
  }
}

output "compute_summary" {
  description = "Summary of all compute instances"
  value = {
    count = length(local.instance_list)
    instances = {
      for instance in local.instance_list :
      instance.id => {
        name         = instance.name
        status       = instance.status
        flavor       = instance.flavor_name
        image        = instance.image_name
        az           = instance.availability_zone
        networks     = instance.network
        key_name     = instance.key_name
        security_groups = instance.security_groups
      }
    }
  }
}

output "security_groups_summary" {
  description = "Summary of all security groups"
  value = {
    count = length(local.secgroup_list)
    security_groups = {
      for sg in local.secgroup_list :
      sg.id => {
        name        = sg.name
        description = sg.description
      }
    }
  }
}

output "rds_summary" {
  description = "Summary of all RDS instances"
  value = {
    count = length(data.opentelekomcloud_rds_instances_v3.all_rds.instances)
    instances = {
      for rds in data.opentelekomcloud_rds_instances_v3.all_rds.instances :
      rds.id => {
        name         = rds.name
        status       = rds.status
        type         = rds.type
        datastore    = rds.datastore
        flavor       = rds.flavor
        volume       = rds.volume
        vpc_id       = rds.vpc_id
        subnet_id    = rds.subnet_id
      }
    }
  }
}

output "loadbalancer_summary" {
  description = "Summary of all load balancers"
  value = {
    count = length(data.opentelekomcloud_lb_loadbalancers_v2.all_loadbalancers.loadbalancers)
    loadbalancers = {
      for lb in data.opentelekomcloud_lb_loadbalancers_v2.all_loadbalancers.loadbalancers :
      lb.id => {
        name                = lb.name
        description         = lb.description
        vip_address         = lb.vip_address
        vip_subnet_id       = lb.vip_subnet_id
        operating_status    = lb.operating_status
        provisioning_status = lb.provisioning_status
      }
    }
  }
}

output "cce_summary" {
  description = "Summary of all CCE clusters"
  value = {
    count = length(data.opentelekomcloud_cce_clusters_v3.all_cce.clusters)
    clusters = {
      for cluster in data.opentelekomcloud_cce_clusters_v3.all_cce.clusters :
      cluster.id => {
        name        = cluster.name
        status      = cluster.status
        cluster_type = cluster.cluster_type
        flavor      = cluster.flavor
        vpc_id      = cluster.vpc_id
        subnet_id   = cluster.subnet_id
      }
    }
  }
}

output "dns_summary" {
  description = "Summary of all DNS zones"
  value = {
    count = length(data.opentelekomcloud_dns_zones_v2.all_dns_zones.zones)
    zones = {
      for zone in data.opentelekomcloud_dns_zones_v2.all_dns_zones.zones :
      zone.id => {
        name        = zone.name
        zone_type   = zone.zone_type
        ttl         = zone.ttl
        record_num  = zone.record_num
        status      = zone.status
      }
    }
  }
}

output "obs_summary" {
  description = "Summary of all OBS buckets"
  value = {
    count = length(data.opentelekomcloud_obs_buckets.all_buckets.buckets)
    buckets = {
      for bucket in data.opentelekomcloud_obs_buckets.all_buckets.buckets :
      bucket.bucket => {
        name          = bucket.bucket
        storage_class = bucket.storage_class
        acl           = bucket.acl
        region        = bucket.region
      }
    }
  }
}

output "dcs_summary" {
  description = "Summary of all DCS instances"
  value = {
    count = length(data.opentelekomcloud_dcs_instances_v1.all_dcs.instances)
    instances = {
      for dcs in data.opentelekomcloud_dcs_instances_v1.all_dcs.instances :
      dcs.id => {
        name         = dcs.name
        status       = dcs.status
        engine       = dcs.engine
        engine_version = dcs.engine_version
        capacity     = dcs.capacity
        vpc_id       = dcs.vpc_id
        subnet_id    = dcs.subnet_id
      }
    }
  }
}

# Generate import commands
output "import_commands" {
  description = "Terraform import commands for existing resources"
  value = {
    vpcs = [
      for vpc in local.vpc_list :
      "terraform import opentelekomcloud_vpc_v1.vpc_${replace(vpc.name, "-", "_")} ${vpc.id}"
    ]
    
    instances = [
      for instance in local.instance_list :
      "terraform import opentelekomcloud_compute_instance_v2.instance_${replace(instance.name, "-", "_")} ${instance.id}"
    ]
    
    security_groups = [
      for sg in local.secgroup_list :
      "terraform import opentelekomcloud_networking_secgroup_v2.sg_${replace(sg.name, "-", "_")} ${sg.id}"
    ]
  }
}