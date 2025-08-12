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

variable "vpc_ids" { 
  type = list(string) 
  default = [
      "cb43c4e5-e25c-4727-b7ce-6b9995edffac",
      "8165c92f-f183-4e22-a1c2-9df880276a11",
      "10f8c808-f6bf-47a8-b3c5-5910bc691900",
      "700af767-115d-43b8-8886-a6a4a63d59ef"
  ]
}