.PHONY: help init plan apply destroy clean validate format check-aws

# Default target
help:
	@echo "VPC Infrastructure Terraform Commands"
	@echo "======================================"
	@echo ""
	@echo "Setup Commands:"
	@echo "  make init       - Initialize Terraform"
	@echo "  make validate   - Validate Terraform configuration"
	@echo "  make format     - Format Terraform files"
	@echo ""
	@echo "Deployment Commands:"
	@echo "  make plan       - Show deployment plan"
	@echo "  make apply      - Deploy infrastructure"
	@echo "  make destroy    - Destroy infrastructure"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make output     - Show Terraform outputs"
	@echo "  make check-aws  - Verify AWS credentials"
	@echo "  make clean      - Clean Terraform cache"
	@echo "  make cost       - Estimate monthly costs"
	@echo ""
	@echo "Testing Commands:"
	@echo "  make test       - Validate and plan without applying"
	@echo ""

# Check AWS credentials
check-aws:
	@echo "Checking AWS credentials..."
	@aws sts get-caller-identity

# Initialize Terraform
init:
	@echo "Initializing Terraform..."
	cd terraform && terraform init

# Validate configuration
validate:
	@echo "Validating Terraform configuration..."
	cd terraform && terraform validate

# Format Terraform files
format:
	@echo "Formatting Terraform files..."
	cd terraform && terraform fmt -recursive

# Show deployment plan
plan: validate
	@echo "Creating deployment plan..."
	cd terraform && terraform plan

# Apply configuration
apply: validate
	@echo "Deploying infrastructure..."
	cd terraform && terraform apply

# Destroy infrastructure
destroy:
	@echo "Destroying infrastructure..."
	@echo "WARNING: This will delete all resources!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform && terraform destroy; \
	fi

# Show outputs
output:
	@cd terraform && terraform output

# Clean Terraform cache
clean:
	@echo "Cleaning Terraform cache..."
	rm -rf terraform/.terraform
	rm -f terraform/.terraform.lock.hcl
	@echo "Cache cleaned. Run 'make init' to reinitialize."

# Test configuration
test: validate plan
	@echo "Configuration validated and plan created successfully!"

# Estimate costs (requires infracost CLI)
cost:
	@which infracost > /dev/null || (echo "infracost not installed. Visit https://www.infracost.io/docs/" && exit 1)
	@cd terraform && infracost breakdown --path .

# Quick deploy (skip plan approval)
quick-apply: validate
	cd terraform && terraform apply -auto-approve

# Show VPC ID
vpc-id:
	@cd terraform && terraform output -raw vpc_id

# Show subnet IDs
subnets:
	@cd terraform && terraform output -json subnet_info | jq

# Show security groups
security-groups:
	@cd terraform && terraform output -json security_groups | jq

# Show NAT Gateway IPs
nat-ips:
	@cd terraform && terraform output -json nat_gateway_public_ips | jq -r '.[]'

# Tail VPC Flow Logs
logs:
	@LOG_GROUP=$$(cd terraform && terraform output -raw flow_logs_cloudwatch_log_group); \
	aws logs tail $$LOG_GROUP --follow

# Show infrastructure summary
summary:
	@cd terraform && terraform output -json infrastructure_summary | jq

# Refresh state
refresh:
	@cd terraform && terraform refresh

# Import existing VPC (use VPC_ID=vpc-xxx make import-vpc)
import-vpc:
	@if [ -z "$(VPC_ID)" ]; then \
		echo "Error: VPC_ID not set. Usage: make import-vpc VPC_ID=vpc-xxx"; \
		exit 1; \
	fi
	cd terraform && terraform import aws_vpc.main $(VPC_ID)

# Create tfvars from example
create-tfvars:
	@if [ ! -f terraform/terraform.tfvars ]; then \
		cp terraform/terraform.tfvars terraform/terraform.tfvars; \
		echo "Created terraform.tfvars. Please edit with your settings."; \
	else \
		echo "terraform.tfvars already exists."; \
	fi

# Full setup workflow
setup: check-aws init validate
	@echo "Setup complete! Next steps:"
	@echo "1. Edit terraform/terraform.tfvars with your settings"
	@echo "2. Run 'make plan' to preview changes"
	@echo "3. Run 'make apply' to deploy"

# Full deployment workflow
deploy: init plan apply output
	@echo "Deployment complete!"
	@echo "Run 'make summary' to see infrastructure overview"
