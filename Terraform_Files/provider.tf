# provider.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = "~> 1.36"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "opentelekomcloud" {
  auth_url = "https://iam.eu-de.otc.t-systems.com/v3"
  region   = var.region

  access_key = var.access_key_id
  secret_key = var.secret_access_key

  # Scoping
  user_domain_name    = var.domain_name
  project_domain_name = var.domain_name
  tenant_id           = var.tenant_id # prefer ID; or use tenant_name instead
}
