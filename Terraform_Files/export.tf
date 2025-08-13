# export.tf
# terraform {
#   required_providers {
#     local = { source = "hashicorp/local", version = "~> 2.5" }
#   }
# }

resource "local_sensitive_file" "otc_inventory_yaml" {
  filename        = "otc-inventory.yaml"
  content         = yamlencode(local.payload)
  file_permission = "0600"
}
