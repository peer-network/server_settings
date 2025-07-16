# versions.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = "~> 1.36"
    }
  }
}

# terraform {
#   required_providers {
#     openstack = {
#       source  = "terraform-provider-openstack/openstack"
#       version = "~> 1.54.0"
#     }
#   }
# }