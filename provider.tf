provider "opentelekomcloud" {
    auth_url    = var.auth_url
    domain_name = var.domain_name
    tenant_name = var.tenant_name
    user_name   = var.user_name
    password    = var.password != null ? var.password : lookup(var.env_vars, "OTC_PASSWORD", "")
    region      = var.region
    access_key  = var.user_name
    secret_key  = var.password
}