# provider.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = "~> 1.36"
    }
    # Insert local here
  }
}

provider "opentelekomcloud" {
  access_key  = var.access_key_id
  secret_key  = var.secret_access_key
  region      = var.region 

  # Scoping
  domain_name = var.domain_name
  tenant_name = var.tenant_name
  auth_url    = "https://iam.eu-de.otc.t-systems.com/v3"
}

#      local = {
#      source  = "hashicorp/local"
#      version = "~> 2.5"
#    }