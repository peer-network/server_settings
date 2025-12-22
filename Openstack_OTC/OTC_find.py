#!/usr/bin/env python3
import openstack
import json

conn = openstack.connect(cloud='otc')


def get_account_context(conn):
    # Pull from clouds.yaml/env via openstacksdk’s CloudRegion
    auth = conn.config.get_auth_args()  # dict: auth_url, project_name, user_domain_name, etc.

    auth_url     = auth.get("auth_url")
    region_name  = conn.config.region_name
    interface    = getattr(conn.config, "interface", None)

    # Names from config (Keystone v3 uses "project", old v2 used "tenant")
    project_name = auth.get("project_name") or auth.get("tenant_name")
    domain_name  = (auth.get("user_domain_name")
                    or auth.get("project_domain_name")
                    or auth.get("domain_name"))

    # Resolve IDs from names (ignore_missing=True keeps this resilient if names are absent)
    project = conn.identity.find_project(project_name, ignore_missing=True) if project_name else None
    domain  = conn.identity.find_domain(domain_name,   ignore_missing=True) if domain_name  else None

    # Availability zones
    try:
        compute_az = [az.name for az in conn.compute.availability_zones()]
    except Exception:
        compute_az = []
    try:
        volume_az = [az.name for az in conn.block_storage.availability_zones()]
    except Exception:
        volume_az = []

    # External networks (useful for TF variables)
    try:
        external_nets = [n.name for n in conn.network.networks(is_router_external=True)]
    except Exception:
        external_nets = []

    # Service catalog summary (optional but nice to have)
    services = []
    try:
        for svc in conn.identity.services():
            eps = [
                {"region": ep.region, "interface": ep.interface, "url": ep.url}
                for ep in conn.identity.endpoints(service_id=svc.id)
            ]
            services.append({"type": svc.type, "name": svc.name, "endpoints": eps})
    except Exception:
        pass

    return {
        "cloud": conn.config.name,
        "auth_url": auth_url,
        "region_name": region_name,
        "interface": interface,
        "project": {
            "name": project_name,
            "id": getattr(project, "id", None),
        },
        "domain": {
            "name": domain_name,
            "id": getattr(domain, "id", None),
        },
        "availability_zones": {
            "compute": compute_az,
            "volume":  volume_az,
        },
        "external_networks": external_nets,
        "service_catalog": services,
    }



result = {
    "account": get_account_context(conn), 
    "servers": [],
    "networks": {
        "vpcs": [],
        "floating_ips": [],
        "orphan_ports": []
    }
}

ecs_ids = set()

# === Servers ===
for server in conn.compute.servers(details=True):
    server_entry = {
        "name": server.name,
        "id": server.id,
        "status": server.status,
        "flavor": server.flavor.get("original_name", "unknown"),
        "fixed_ips": [],
        "floating_ips": [],
        "ports": [],
        "security_groups": []
    }

    ecs_ids.add(server.id)

    # Ports
    ports = list(conn.network.ports(device_id=server.id))
    for port in ports:
        server_entry["ports"].append({
            "id": port.id,
            "mac_address": port.mac_address,
            "fixed_ips": port.fixed_ips
        })
        for ip in port.fixed_ips:
            server_entry["fixed_ips"].append(ip["ip_address"])

        # Floating IPs
        for fip in conn.network.ips(port_id=port.id):
            server_entry["floating_ips"].append(fip.floating_ip_address)

    # Security groups
    if server.security_groups:
        for sg in server.security_groups:
            sg_detail = conn.network.find_security_group(sg["name"])
            server_entry["security_groups"].append({
                "name": sg["name"],
                "rules": [
                    {
                        "direction": r["direction"],
                        "ethertype": r["ethertype"],
                        "protocol": r["protocol"],
                        "port_range_min": r["port_range_min"],
                        "port_range_max": r["port_range_max"],
                        "remote_ip_prefix": r["remote_ip_prefix"]
                    } for r in sg_detail.security_group_rules
                ]
            })

    result["servers"].append(server_entry)

# === VPCs / Networks ===
for net in conn.network.networks():
    vpc_entry = {
        "id": net.id,
        "name": net.name,
        "is_external": net.is_router_external,
        "subnets": [],
        "ports": []
    }

for subnet_id in net.subnet_ids:
    try:
        subnet = conn.network.get_subnet(subnet_id)
        vpc_entry["subnets"].append({
            "id": subnet.id,
            "name": subnet.name,
            "cidr": subnet.cidr,
            "gateway_ip": subnet.gateway_ip
        })
    except openstack.exceptions.ResourceNotFound:
        print(f"⚠️ Warning: Subnet {subnet_id} not found. Skipping.")
    except Exception as e:
        print(f"⚠️ Unexpected error fetching subnet {subnet_id}: {e}")

    # Ports in this VPC
    for port in conn.network.ports(network_id=net.id):
        vpc_entry["ports"].append({
            "id": port.id,
            "mac": port.mac_address,
            "device_owner": port.device_owner,
            "device_id": port.device_id,
            "fixed_ips": port.fixed_ips
        })

        # If port device is not ECS, consider it external/orphan
        if port.device_id not in ecs_ids and port.device_owner not in ("network:router_interface", ""):
            result["networks"]["orphan_ports"].append({
                "id": port.id,
                "device_owner": port.device_owner,
                "device_id": port.device_id,
                "mac": port.mac_address,
                "fixed_ips": port.fixed_ips
            })

    result["networks"]["vpcs"].append(vpc_entry)

# === Floating IPs ===
for fip in conn.network.ips():
    result["networks"]["floating_ips"].append({
        "id": fip.id,
        "floating_ip_address": fip.floating_ip_address,
        "fixed_ip_address": fip.fixed_ip_address,
        "port_id": fip.port_id,
        "status": fip.status
    })

# === Output ===
with open("Peer_OTC_map.json", "w") as f:
    json.dump(result, f, indent=2)

print("✅ Structured network + server map saved to Peer_OTC_map.json")
