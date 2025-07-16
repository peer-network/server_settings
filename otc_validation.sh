#!/bin/bash
# otc_validation.sh - Validate OTC provider and discover resources

echo "=== OTC Terraform Validation and Discovery ==="
echo "Account: OTC00000000001000122968"
echo "Date: $(date)"
echo

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "❌ Terraform not initialized. Run 'terraform init' first."
    exit 1
fi

echo "✅ Terraform initialized"

# Validate configuration
echo "🔍 Validating Terraform configuration..."
if terraform validate; then
    echo "✅ Configuration is valid"
else
    echo "❌ Configuration has errors"
    exit 1
fi

# Check provider version
echo "🔍 Checking provider version..."
terraform version

# Plan with detailed output
echo "🔍 Running terraform plan..."
terraform plan -out=tfplan

# Show plan in JSON format
echo "🔍 Generating JSON plan..."
terraform show -json tfplan > tfplan.json

# Extract data source information
echo "🔍 Analyzing available data sources..."
jq -r '.planned_values.root_module.resources[] | select(.mode == "data") | "\(.type): \(.name)"' tfplan.json | sort

# Check for any errors in planned values
echo "🔍 Checking for planning errors..."
jq -r '.errors[]?' tfplan.json 2>/dev/null || echo "No errors found in plan"

# Generate resource discovery report
echo "🔍 Generating resource discovery report..."
cat > resource_discovery.py << 'EOF'
#!/usr/bin/env python3
import json
import sys

def analyze_plan(plan_file):
    with open(plan_file, 'r') as f:
        plan = json.load(f)
    
    print("\n=== RESOURCE DISCOVERY REPORT ===\n")
    
    # Analyze planned values
    resources = plan.get('planned_values', {}).get('root_module', {}).get('resources', [])
    
    data_sources = [r for r in resources if r.get('mode') == 'data']
    managed_resources = [r for r in resources if r.get('mode') == 'managed']
    
    print(f"📊 Summary:")
    print(f"   Data Sources: {len(data_sources)}")
    print(f"   Managed Resources: {len(managed_resources)}")
    print()
    
    # Group by type
    data_by_type = {}
    for ds in data_sources:
        ds_type = ds.get('type')
        if ds_type not in data_by_type:
            data_by_type[ds_type] = []
        data_by_type[ds_type].append(ds)
    
    print("📋 Data Sources by Type:")
    for ds_type, sources in data_by_type.items():
        print(f"   {ds_type}: {len(sources)} instances")
        for source in sources:
            name = source.get('name', 'unnamed')
            print(f"     - {name}")
    print()
    
    # Check for configuration issues
    config = plan.get('configuration', {})
    if 'provider_config' in config:
        print("⚙️  Provider Configuration:")
        for provider, config_data in config['provider_config'].items():
            print(f"   {provider}: {config_data.get('name', 'N/A')}")
    
    # Check for any resource changes
    resource_changes = plan.get('resource_changes', [])
    if resource_changes:
        print(f"\n🔄 Planned Changes: {len(resource_changes)}")
        for change in resource_changes:
            action = change.get('change', {}).get('actions', [])
            print(f"   {change.get('type')}.{change.get('name')}: {action}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 resource_discovery.py <tfplan.json>")
        sys.exit(1)
    
    analyze_plan(sys.argv[1])
EOF

python3 resource_discovery.py tfplan.json

# Generate corrected jq commands for the actual state
echo "🔍 Generating corrected jq commands..."
cat > jq_commands.sh << 'EOF'
#!/bin/bash
# Corrected jq commands for OTC state analysis

echo "=== JQ Commands for OTC State Analysis ==="

# After terraform apply, use these commands:

# 1. Get all VPCs
echo "# Get all VPCs:"
echo "jq '.values.root_module.resources[] | select(.type==\"opentelekomcloud_vpc_v1\") | {name: .values.name, id: .values.id, cidr: .values.cidr}' terraform.tfstate"

# 2. Get all subnets
echo "# Get all subnets:"
echo "jq '.values.root_module.resources[] | select(.type==\"opentelekomcloud_vpc_subnet_v1\") | {name: .values.name, id: .values.id, cidr: .values.cidr, vpc_id: .values.vpc_id}' terraform.tfstate"

# 3. Get all compute instances
echo "# Get all compute instances:"
echo "jq '.values.root_module.resources[] | select(.type==\"opentelekomcloud_compute_instance_v2\") | {name: .values.name, id: .values.id, status: .values.status, flavor: .values.flavor_name}' terraform.tfstate"

# 4. Get all security groups
echo "# Get all security groups:"
echo "jq '.values.root_module.resources[] | select(.type==\"opentelekomcloud_networking_secgroup_v2\") | {name: .values.name, id: .values.id, description: .values.description}' terraform.tfstate"

# 5. Get resource counts by type
echo "# Get resource counts by type:"
echo "jq -r '.values.root_module.resources[].type' terraform.tfstate | sort | uniq -c"

# 6. Generate import commands
echo "# Generate import commands:"
echo "jq -r '.values.root_module.resources[] | select(.type==\"opentelekomcloud_compute_instance_v2\") | \"terraform import opentelekomcloud_compute_instance_v2.\\(.values.name) \\(.values.id)\"' terraform.tfstate"

EOF

chmod +x jq_commands.sh
echo "✅ Generated jq_commands.sh for state analysis"

# Clean up
rm -f tfplan

echo
echo "=== NEXT STEPS ==="
echo "1. Review the resource discovery report above"
echo "2. If no errors, run: terraform apply"
echo "3. After apply, run: terraform show -json > terraform.tfstate"
echo "4. Use the generated jq_commands.sh to analyze your state"
echo "5. Use the import commands from outputs to import existing resources"
echo
echo "=== FILES CREATED ==="
echo "- resource_discovery.py: Python script for plan analysis"
echo "- jq_commands.sh: JQ commands for state analysis"
echo "- tfplan.json: Terraform plan in JSON format"