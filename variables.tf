# variables.tf
variable "tenant_name" {
  description = "OTC account name"
  type        = string
  default     = "OTC00000000001000122968"
}

variable "auth_url" {
  description = "OTC auth url"
  type        = string
  default     = "https://iam.eu-de.otc.t-systems.com/v3"
}

variable "region" {
  description = "OTC region"
  type        = string
  default     = "eu-de"
}

variable "domain_name" {
  description = "OTC domain"
  type        = string
  default     = "TC00000000001000122968"
}

variable "user_name" {
  description = "OTC access user"
  type        = string
  sensitive   = true
}

variable "password" {
  description = "password"
  type        = string
  sensitive   = true
}

# Environment-specific variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "peer-network"
}