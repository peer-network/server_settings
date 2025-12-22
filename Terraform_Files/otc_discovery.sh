#!/bin/bash
# otc_discovery.sh - Step-by-step discovery of OTC resources

echo "=== OTC Resource Discovery Script ==="
echo "Account: OTC00000000001000122968"
echo "Date: $(date)"
echo

# Function to test a single data source
test_data_source() {
    local resource_type=$1
    local resource_name=$2
    
    echo "Testing: $resource_type.$resource_name"
    
    # Create a minimal test configuration
    cat > test_${resource_name}.tf << EOF
data "$resource_type" "$resource_name" {}

output "test_${resource_name}" {
  value = data.$resource_type.$resource_name
}
EOF
    
    # Test the configuration
    if terraform validate > /dev/null 2>&1; then
        echo "✅ $resource_type.$resource_name - Configuration valid"
        
        # Try to plan
        if terraform plan -target=data.$resource_type.$resource_name > /dev/null 2>&1; then
            echo "✅ $resource_type.$resource_name - Plan successful"
            return 0
        else
            echo "❌ $resource_type.$resource_name - Plan failed"
            terraform plan -target=data.$resource_type.$resource_name 2>&1 | head -5
            return 1
        fi
    else
        echo "❌ $resource_type.$resource_name - Configuration invalid"
        terraform validate 2>&1 | head -3
        return 1
    fi
}

# Function to cleanup test files
cleanup() {
    rm -f test_*.tf
}

# Start testing
echo "🔍 Testing OTC data sources..."
echo

# Test basic data sources one by one
declare -A data_sources=(
    ["opentelekomcloud_identity_project_v3"]="current"
    ["opentelekomcloud_vpc_v1"]="default"
    ["opentelekomcloud_vpc_subnet_v1"]="default"
    ["opentelekomcloud_compute_instances_v2"]="all"
    ["opentelekomcloud_ecs_instances_v1"]="all"
    ["opentelekomcloud_networking_secgroup_v2"]="all"
    ["opentelekomcloud_compute_flavors_v2"]="all"
    ["opentelekomcloud_images_image_v2"]="latest"
    ["opentelekomcloud_compute_keypairs_v2"]="all"
    ["opentelekomcloud_rds_instances_v3"]="all"
    ["opentelekomcloud_lb_loadbalancers_v2"]="all"
    ["opentelekomcloud_cce_clusters_v3"]="all"
    ["opentelekomcloud_dns_zones_v2"]="all"
    ["opentelekomcloud_obs_buckets"]="all"
    ["opentelekomcloud_dcs_instances_v1"]="all"
    ["opentelekomcloud_networking_network_v2"]="all"
    ["opentelekomcloud_vpc_peering_connections_v2"]="all"
    ["opentelekomcloud_vpc_eips_v1"]="all"
)

working_sources=()
failed_sources=()

for source in "${!data_sources[@]}"; do
    name=${data_sources[$source]}
    if test_data_source "$source" "$name"; then
        working_sources+=("$source")
    else
        failed_sources+=("$source")
    fi
    echo
done

# Generate working configuration
echo "=== GENERATING WORKING CONFIGURATION ==="
echo

cat > working_main.tf << 'EOF'
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

EOF

echo "Adding working data sources to working_main.tf..."
for source in "${working_sources[@]}"; do
    name=${data_sources[$source]}
    echo "data \"$source\" \"$name\" {}" >> working_main.tf
    
    # Add specific configurations for certain data sources
    case $source in
        "opentelekomcloud_images_image_v2")
            sed -i "s/data \"$source\" \"$name\" {}/data \"$source\" \"$name\" {\n  most_recent = true\n}/" working_main.tf
            ;;
    esac
    
    echo >> working_main.tf
done

# Add locals and outputs
cat >> working_main.tf << 'EOF'
locals {
EOF

for source in "${working_sources[@]}"; do
    name=${data_sources[$source]}
    case $source in
        *"instances"*)
            echo "  ${name}_list = try(data.$source.$name.instances, [])" >> working_main.tf
            ;;
        *"clusters"*)
            echo "  ${name}_list = try(data.$source.$name.clusters, [])" >> working_main.tf
            ;;
        *"zones"*)
            echo "  ${name}_list = try(data.$source.$name.zones, [])" >> working_main.tf
            ;;
        *"buckets"*)
            echo "  ${name}_list = try(data.$source.$name.buckets, [])" >> working_main.tf
            ;;
        *"security_groups"*)
            echo "  ${name}_list = try(data.$source.$name.security_groups, [])" >> working_main.tf
            ;;
        *"loadbalancers"*)
            echo "  ${name}_list = try(data.$source.$name.loadbalancers, [])" >> working_main.tf
            ;;
        *"networks"*)
            echo "  ${name}_list = try(data.$source.$name.networks, [])" >> working_main.tf
            ;;
        *"eips"*)
            echo "  ${name}_list = try(data.$source.$name.eips, [])" >> working_main.tf
            ;;
        *"peering_connections"*)
            echo "  ${name}_list = try(data.$source.$name.peering_connections, [])" >> working_main.tf
            ;;
        *)
            echo "  ${name}_data = try(data.$source.$name, null)" >> working_main.tf
            ;;
    esac
done

cat >> working_main.tf << 'EOF'
}

# Simple outputs for validation
output "discovery_summary" {
  description = "Summary of discovered resources"
  value = {
EOF

for source in "${working_sources[@]}"; do
    name=${data_sources[$source]}
    case $source in
        *"instances"*|*"clusters"*|*"zones"*|*"buckets"*|*"security_groups"*|*"loadbalancers"*|*"networks"*|*"eips"*|*"peering_connections"*)
            echo "    ${name}_count = length(local.${name}_list)" >> working_main.tf
            ;;
        *)
            echo "    ${name}_available = local.${name}_data != null" >> working_main.tf
            ;;
    esac
done

cat >> working_main.tf << 'EOF'
  }
}
EOF

# Create comprehensive outputs
cat > working_outputs.tf << 'EOF'
# working_outputs.tf - Generated outputs for working data sources
EOF

for source in "${working_sources[@]}"; do
    name=${data_sources[$source]}
    cat >> working_outputs.tf << EOF
output "${name}_details" {
  description = "Details from $source"
  value = try(data.$source.$name, null)
}

EOF
done

# Generate summary
echo "=== SUMMARY ==="
echo
echo "✅ Working data sources (${#working_sources[@]}):"
for source in "${working_sources[@]}"; do
    echo "   - $source"
done
echo

echo "❌ Failed data sources (${#failed_sources[@]}):"
for source in "${failed_sources[@]}"; do
    echo "   - $source"
done
echo

echo "=== FILES GENERATED ==="
echo "- working_main.tf: Configuration with only working data sources"
echo "- working_outputs.tf: Outputs for all working data sources"
echo

echo "=== NEXT STEPS ==="
echo "1. Review working_main.tf and working_outputs.tf"
echo "2. Replace your main.tf with working_main.tf"
echo "3. Run: terraform plan"
echo "4. Run: terraform apply"
echo "5. Examine outputs to understand your infrastructure"
echo

# Cleanup
cleanup

echo "=== QUICK TEST ==="
echo "Testing the generated configuration..."
mv main.tf main.tf.backup
cp working_main.tf main.tf

if terraform validate; then
    echo "✅ Generated configuration is valid!"
    echo "You can now run: terraform plan"
else
    echo "❌ Generated configuration has issues"
    echo "Restoring original main.tf"
    mv main.tf.backup main.tf
fi

echo
echo "Discovery complete!"