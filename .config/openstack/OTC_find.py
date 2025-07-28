#!/usr/bin/python3

#!/usr/bin/env python3
import openstack
import json

conn = openstack.connect(cloud='otc')

inventory = {}

# Servers and IPs
inventory["servers"] = []
for server in conn.compute.servers(details=True):
    ports = list(conn.network.ports(device_id=server.id))
    fixed_ips = []
    floating_ips = []
    secgroups = server.security_groups or []

    for port in ports:
        fixed_ips.extend([ip["ip_address"] for ip in port.fixed_ips])
        for fip in conn.network.ips(port_id=port.id):
            floating_ips.append(fip.floating_ip_address)

    inventory["servers"].append({
        "name": server.name,
        "id": server.id,
        "status": server.status,
        "flavor": server.flavor["original_name"],
        "fixed_ips": fixed_ips,
        "floating_ips": floating_ips,
        "security_groups": [sg["name"] for sg in secgroups]
    })

# Networks
inventory["networks"] = []
for net in conn.network.networks():
    inventory["networks"].append({
        "id": net.id,
        "name": net.name,
        "subnets": net.subnet_ids,
        "router:external": net.is_router_external
    })

# Subnets
inventory["subnets"] = []
for subnet in conn.network.subnets():
    inventory["subnets"].append({
        "id": subnet.id,
        "name": subnet.name,
        "cidr": subnet.cidr,
        "gateway_ip": subnet.gateway_ip,
        "network_id": subnet.network_id
    })

# Floating IPs
inventory["floating_ips"] = []
for fip in conn.network.ips():
    inventory["floating_ips"].append({
        "id": fip.id,
        "floating_ip_address": fip.floating_ip_address,
        "fixed_ip_address": fip.fixed_ip_address,
        "port_id": fip.port_id,
        "status": fip.status
    })

# Security Groups
inventory["security_groups"] = []
for sg in conn.network.security_groups():
    inventory["security_groups"].append({
        "id": sg.id,
        "name": sg.name,
        "description": sg.description,
        "rules": [
            {
                "direction": rule["direction"],
                "ethertype": rule["ethertype"],
                "protocol": rule["protocol"],
                "port_range_min": rule["port_range_min"],
                "port_range_max": rule["port_range_max"],
                "remote_ip_prefix": rule["remote_ip_prefix"]
            } for rule in sg.security_group_rules
        ]
    })

# Write to file
with open("Peer_Network.json", "w") as f:
    json.dump(inventory, f, indent=2)

print("✅ Network and security map written to network_map.json")
