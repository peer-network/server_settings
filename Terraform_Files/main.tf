
# ### Grab the data fro OTC
# ##


# data "opentelekomcloud_vpc_subnet_ids_v1" "subnet_ids" {
#   vpc_id = var.vpc_id
# }

# data "opentelekomcloud_vpc_subnet_v1" "subnet" {
#   for_each = data.opentelekomcloud_vpc_subnet_ids_v1.subnet_ids.ids
#   id       = each.value
# }

# # output "subnet_cidr_blocks" {
# #   value = [for s in data.opentelekomcloud_vpc_subnet_v1.subnet : s.cidr]
# # }


# # Get current region and project info
# data "opentelekomcloud_identity_project_v3" "current" {}

# # Simple approach - discover resources without complex for_each loops
# # VPC data source (single VPC query - you may need to specify filters)
# data "opentelekomcloud_vpc_v1" "default" {
#   # You can add filters here if needed
#   # name = "default"
# }

# data "opentelekomcloud_evs_volumes_v2" "all" {}

# # Compute instances data source  
# data "opentelekomcloud_compute_instances_v2" "all" {}

# # Security Groups
# data "opentelekomcloud_networking_secgroup_v2" "all" {}

# # Available flavors
# data "opentelekomcloud_compute_flavor_v2" "all" {}

# # Available images
# data "opentelekomcloud_images_image_v2" "latest" {
#   most_recent = true
# }



# # # Get current region and project info
# # data "opentelekomcloud_identity_project_v3" "current" {}


# # # ECS instances (list)
# # data "opentelekomcloud_compute_instances_v2" "all" {}

# # # EVS volumes (list)
# # data "opentelekomcloud_evs_volumes_v2" "all" {}


# data "opentelekomcloud_vpc_subnet_ids_v1" "subnets" {
#   for_each = toset(var.vpc_ids)
#   vpc_id   = each.value
# }


# # Subnets -> get IDs then hydrate details
# locals {
#   all_subnet_ids = flatten([for d in data.opentelekomcloud_vpc_subnet_ids_v1.subnets : d.ids])
# }


# data "opentelekomcloud_vpc_subnet_v1" "subnet" {
#   for_each = toset(local.all_subnet_ids)
#   id       = each.value
# }


# # Ports -> get IDs then hydrate details
# data "opentelekomcloud_networking_port_ids_v2" "all" {}
# data "opentelekomcloud_networking_port_v2" "port" {
#   for_each = toset(data.opentelekomcloud_networking_port_ids_v2.all.ids)
#   port_id  = each.value
# }