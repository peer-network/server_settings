terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.0"
    }
  }
}

# Configure the OpenStack Provider for Telekom Cloud
provider "openstack" {
  auth_url    = var.auth_url
  domain_name = var.domain_name
  tenant_name = var.tenant_name
  user_name   = var.user_name
  password    = var.password != null ? var.password : lookup(var.env_vars, "OTC_PASSWORD", "")
  region      = var.region
}


# Environment variables lookup
variable "env_vars" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

# Variables
variable "auth_url" {
  description = "OpenStack auth URL"
  type        = string
  default     = "https://iam.eu-de.otc.t-systems.com/v3"  # EU-DE region
}

variable "domain_name" {
  description = "OpenStack domain name"
  type        = string
}

variable "tenant_name" {
  description = "OpenStack tenant/project name"
  type        = string
}

variable "user_name" {
  description = "OpenStack username"
  type        = string
}

variable "password" {
  description = "OpenStack password"
  type        = string
  sensitive   = true
  default     = null  # Will be populated from environment variable
}

variable "region" {
  description = "OpenStack region"
  type        = string
  default     = "eu-de"
}