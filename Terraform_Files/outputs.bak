# outputs.tf - Fixed for actual OTC provider structure
output "account_info" {
  description = "Current OTC account information"
  value = {
    project_id   = local.project_id
    project_name = local.project_name
    region       = var.region
    tenant_name  = var.tenant_name
    account_name = var.user_name
  }
}

output "vpc_info" {
  description = "VPC information"
  value = {
    id     = try(data.opentelekomcloud_vpc_v1.default.id, null)
    name   = try(data.opentelekomcloud_vpc_v1.default.name, null)
    cidr   = try(data.opentelekomcloud_vpc_v1.default.cidr, null)
    status = try(data.opentelekomcloud_vpc_v1.default.status, null)
  }
}

output "subnet_info" {
  description = "Subnet information"
  value = {
    id                = try(data.opentelekomcloud_vpc_subnet_v1.default.id, null)
    name              = try(data.opentelekomcloud_vpc_subnet_v1.default.name, null)
    cidr              = try(data.opentelekomcloud_vpc_subnet_v1.default.cidr, null)
    vpc_id            = try(data.opentelekomcloud_vpc_subnet_v1.default.vpc_id, null)
    gateway_ip        = try(data.opentelekomcloud_vpc_subnet_v1.default.gateway_ip, null)
    availability_zone = try(data.opentelekomcloud_vpc_subnet_v1.default.availability_zone, null)
  }
}

output "compute_instances_summary" {
  description = "Summary of compute instances"
  value = {
    count = length(local.compute_instances)
    instances = {
      for instance in local.compute_instances :
      instance.id => {
        name            = instance.name
        status          = instance.status
        flavor          = try(instance.flavor_name, instance.flavor)
        image           = try(instance.image_name, instance.image)
        availability_zone = try(instance.availability_zone, null)
        networks        = try(instance.network, instance.networks, [])
        key_name        = try(instance.key_name, null)
        security_groups = try(instance.security_groups, [])
      }
    }
  }
}

output "ecs_instances_summary" {
  description = "Summary of ECS instances"
  value = {
    count = length(local.ecs_instances)
    instances = {
      for instance in local.ecs_instances :
      instance.id => {
        name              = instance.name
        status            = instance.status
        flavor            = try(instance.flavor, null)
        image             = try(instance.image, null)
        availability_zone = try(instance.availability_zone, null)
        vpc_id            = try(instance.vpc_id, null)
        subnet_id         = try(instance.subnet_id, null)
      }
    }
  }
}

output "security_groups_summary" {
  description = "Summary of security groups"
  value = {
    count = length(local.security_groups)
    security_groups = {
      for sg in local.security_groups :
      sg.id => {
        name        = sg.name
        description = try(sg.description, null)
        tenant_id   = try(sg.tenant_id, null)
      }
    }
  }
}

output "rds_summary" {
  description = "Summary of RDS instances"
  value = {
    count = length(local.rds_instances)
    instances = {
      for rds in local.rds_instances :
      rds.id => {
        name         = rds.name
        status       = rds.status
        type         = try(rds.type, null)
        datastore    = try(rds.datastore, null)
        flavor       = try(rds.flavor, null)
        volume       = try(rds.volume, null)
        vpc_id       = try(rds.vpc_id, null)
        subnet_id    = try(rds.subnet_id, null)
      }
    }
  }
}

output "loadbalancer_summary" {
  description = "Summary of load balancers"
  value = {
    count = length(local.loadbalancers)
    loadbalancers = {
      for lb in local.loadbalancers :
      lb.id => {
        name                = lb.name
        description         = try(lb.description, null)
        vip_address         = try(lb.vip_address, null)
        vip_subnet_id       = try(lb.vip_subnet_id, null)
        operating_status    = try(lb.operating_status, null)
        provisioning_status = try(lb.provisioning_status, null)
      }
    }
  }
}

output "cce_summary" {
  description = "Summary of CCE clusters"
  value = {
    count = length(local.cce_clusters)
    clusters = {
      for cluster in local.cce_clusters :
      cluster.id => {
        name         = cluster.name
        status       = try(cluster.status, null)
        cluster_type = try(cluster.cluster_type, null)
        flavor       = try(cluster.flavor, null)
        vpc_id       = try(cluster.vpc_id, null)
        subnet_id    = try(cluster.subnet_id, null)
      }
    }
  }
}

output "dns_summary" {
  description = "Summary of DNS zones"
  value = {
    count = length(local.dns_zones)
    zones = {
      for zone in local.dns_zones :
      zone.id => {
        name       = zone.name
        zone_type  = try(zone.zone_type, null)
        ttl        = try(zone.ttl, null)
        record_num = try(zone.record_num, null)
        status     = try(zone.status, null)
      }
    }
  }
}

output "obs_summary" {
  description = "Summary of OBS buckets"
  value = {
    count = length(local.obs_buckets)
    buckets = {
      for bucket in local.obs_buckets :
      bucket.bucket => {
        name          = bucket.bucket
        storage_class = try(bucket.storage_class, null)
        acl           = try(bucket.acl, null)
        region        = try(bucket.region, null)
      }
    }
  }
}

output "dcs_summary" {
  description = "Summary of DCS instances"
  value = {
    count = length(local.dcs_instances)
    instances = {
      for dcs in local.dcs_instances :
      dcs.id => {
        name           = dcs.name
        status         = try(dcs.status, null)
        engine         = try(dcs.engine, null)
        engine_version = try(dcs.engine_version, null)
        capacity       = try(dcs.capacity, null)
        vpc_id         = try(dcs.vpc_id, null)
        subnet_id      = try(dcs.subnet_id, null)
      }
    }
  }
}

output "networks_summary" {
  description = "Summary of networks"
  value = {
    count = length(local.networks)
    networks = {
      for network in local.networks :
      network.id => {
        name           = network.name
        status         = try(network.status, null)
        admin_state_up = try(network.admin_state_up, null)
        shared         = try(network.shared, null)
        tenant_id      = try(network.tenant_id, null)
      }
    }
  }
}

output "eips_summary" {
  description = "Summary of Elastic IPs"
  value = {
    count = length(local.eips)
    eips = {
      for eip in local.eips :
      eip.id => {
        status      = try(eip.status, null)
        type        = try(eip.type, null)
        public_ip   = try(eip.public_ip, null)
        private_ip  = try(eip.private_ip, null)
        port_id     = try(eip.port_id, null)
        tenant_id   = try(eip.tenant_id, null)
      }
    }
  }
}

output "peering_connections_summary" {
  description = "Summary of VPC peering connections"
  value = {
    count = length(local.peering_connections)
    connections = {
      for conn in local.peering_connections :
      conn.id => {
        name           = conn.name
        status         = try(conn.status, null)
        vpc_id         = try(conn.vpc_id, null)
        peer_vpc_id    = try(conn.peer_vpc_id, null)
        peer_tenant_id = try(conn.peer_tenant_id, null)
      }
    }
  }
}

# Generate import commands based on discovered resources
output "import_commands" {
  description = "Terraform import commands for existing resources"
  value = {
    vpc = try(
      "terraform import opentelekomcloud_vpc_v1.default ${data.opentelekomcloud_vpc_v1.default.id}",
      "# No VPC found"
    )
    
    subnet = try(
      "terraform import opentelekomcloud_vpc_subnet_v1.default ${data.opentelekomcloud_vpc_subnet_v1.default.id}",
      "# No subnet found"
    )
    
    compute_instances = [
      for instance in local.compute_instances :
      "terraform import opentelekomcloud_compute_instance_v2.${replace(instance.name, "-", "_")} ${instance.id}"
    ]
    
    ecs_instances = [
      for instance in local.ecs_instances :
      "terraform import opentelekomcloud_ecs_instance_v1.${replace(instance.name, "-", "_")} ${instance.id}"
    ]
    
    security_groups = [
      for sg in local.security_groups :
      "terraform import opentelekomcloud_networking_secgroup_v2.${replace(sg.name, "-", "_")} ${sg.id}"
    ]
    
    rds_instances = [
      for rds in local.rds_instances :
      "terraform import opentelekomcloud_rds_instance_v3.${replace(rds.name, "-", "_")} ${rds.id}"
    ]
  }
}

# Summary of all resources
output "resource_summary" {
  description = "Summary of all discovered resources"
  value = {
    compute_instances      = length(local.compute_instances)
    ecs_instances         = length(local.ecs_instances)
    security_groups       = length(local.security_groups)
    rds_instances         = length(local.rds_instances)
    loadbalancers         = length(local.loadbalancers)
    cce_clusters          = length(local.cce_clusters)
    dns_zones             = length(local.dns_zones)
    obs_buckets           = length(local.obs_buckets)
    dcs_instances         = length(local.dcs_instances)
    networks              = length(local.networks)
    eips                  = length(local.eips)
    peering_connections   = length(local.peering_connections)
    
    total_resources = (
      length(local.compute_instances) +
      length(local.ecs_instances) +
      length(local.security_groups) +
      length(local.rds_instances) +
      length(local.loadbalancers) +
      length(local.cce_clusters) +
      length(local.dns_zones) +
      length(local.obs_buckets) +
      length(local.dcs_instances) +
      length(local.networks) +
      length(local.eips) +
      length(local.peering_connections)
    )
  }
}