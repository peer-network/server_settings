# working_main.tf - Generated from successful data source tests
terraform {
  required_version = ">= 1.0"
  required_providers {
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = "~> 1.36"
    }
  }
}

provider "opentelekomcloud" {
  access_key  = var.access_key
  secret_key  = var.secret_key
  tenant_name = var.tenant_name
  region      = var.region
}

locals {
}

# Simple outputs for validation
output "discovery_summary" {
  description = "Summary of discovered resources"
  value = {
  }
}
