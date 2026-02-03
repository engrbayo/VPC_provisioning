# Quick Start Guide

Get your secure VPC infrastructure running in under 10 minutes.

## Prerequisites

```bash
# Check Terraform installation
terraform --version  # Should be >= 1.0

# Check AWS CLI configuration
aws sts get-caller-identity
```

## 5-Minute Deploy

### Step 1: Configure Variables (2 minutes)

```bash
cd terraform
cp terraform.tfvars terraform.tfvars.backup
```

Edit `terraform.tfvars`:

```hcl
# REQUIRED: Set your IP for SSH access
allowed_ssh_cidrs = ["YOUR.IP.ADDRESS/32"]

# OPTIONAL: Cost optimization for dev
single_nat_gateway = true  # Use false for production

# OPTIONAL: Reduce retention for dev
flow_logs_retention_days = 7  # Use 30-90 for production
```

### Step 2: Initialize Terraform (1 minute)

```bash
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
...
Terraform has been successfully initialized!
```

### Step 3: Preview Changes (1 minute)

```bash
terraform plan
```

Review the output. You should see approximately 60-80 resources to be created.

### Step 4: Deploy Infrastructure (5 minutes)

```bash
terraform apply
```

Type `yes` when prompted.

Deployment time: ~5-7 minutes (mostly waiting for NAT Gateways)

### Step 5: Verify Deployment (1 minute)

```bash
# View key outputs
terraform output

# Get VPC ID
terraform output vpc_id

# Get NAT Gateway IPs (for allowlisting)
terraform output nat_gateway_public_ips

# View all subnet IDs
terraform output subnet_info
```

## What Was Created?

✅ VPC with DNS enabled  
✅ 6 subnets across 2 availability zones (public, private, data)  
✅ Internet Gateway  
✅ NAT Gateway(s) with Elastic IPs  
✅ 3 route tables with appropriate routes  
✅ 5 security groups with least-privilege rules  
✅ Network ACLs for each tier  
✅ VPC Flow Logs to CloudWatch and S3  
✅ VPC Endpoints for AWS services  

## Test Your Infrastructure

### 1. Verify VPC Flow Logs

```bash
# Get log group name
LOG_GROUP=$(terraform output -raw flow_logs_cloudwatch_log_group)

# View recent logs
aws logs tail $LOG_GROUP --follow
```

### 2. Check Security Groups

```bash
# List all security groups
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --query 'SecurityGroups[*].[GroupName,GroupId]' \
  --output table
```

### 3. Verify Route Tables

```bash
# Public route table should have IGW route
aws ec2 describe-route-tables \
  --route-table-ids $(terraform output -raw public_route_table_id) \
  --query 'RouteTables[*].Routes' \
  --output table

# Data route table should NOT have internet route
aws ec2 describe-route-tables \
  --route-table-ids $(terraform output -raw data_route_table_id) \
  --query 'RouteTables[*].Routes' \
  --output table
```

## Next Steps

### Deploy Application Resources

Now that your VPC is ready, deploy your application:

1. **Launch EC2 instances** in private subnets
2. **Create RDS database** in data subnets
3. **Set up Application Load Balancer** in public subnets
4. **Configure Auto Scaling Groups**

### Example: Launch Test EC2 Instance

```bash
# Get private subnet ID
SUBNET_ID=$(terraform output -json private_subnet_ids | jq -r '.[0]')

# Get app security group ID
SG_ID=$(terraform output -raw app_security_group_id)

# Launch instance
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \  # Amazon Linux 2
  --instance-type t3.micro \
  --subnet-id $SUBNET_ID \
  --security-group-ids $SG_ID \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-app-server}]'
```

### Example: Create RDS Database

```bash
# Create DB subnet group
aws rds create-db-subnet-group \
  --db-subnet-group-name my-db-subnet-group \
  --db-subnet-group-description "Subnets for RDS" \
  --subnet-ids $(terraform output -json data_subnet_ids | jq -r '.[]' | tr '\n' ' ')

# Create database
aws rds create-db-instance \
  --db-instance-identifier mydb \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username admin \
  --master-user-password ChangeMe123! \
  --allocated-storage 20 \
  --db-subnet-group-name my-db-subnet-group \
  --vpc-security-group-ids $(terraform output -raw database_security_group_id)
```

## Common Tasks

### Add Your IP for SSH Access

```hcl
# Edit terraform.tfvars
allowed_ssh_cidrs = ["YOUR.IP.ADDRESS/32"]
```

```bash
terraform apply
```

### Enable Additional VPC Endpoints

```hcl
# Edit terraform.tfvars
vpc_endpoint_services = [
  "s3",
  "ec2",
  "ecr.api",
  "ecr.dkr",
  "logs",
  "secretsmanager",
  "ssm",
  "rds",      # Add RDS
  "lambda"    # Add Lambda
]
```

```bash
terraform apply
```

### Scale to More Availability Zones

```hcl
# Edit terraform.tfvars
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
data_subnet_cidrs    = ["10.0.100.0/24", "10.0.200.0/24", "10.0.250.0/24"]
```

```bash
terraform apply
```

## Troubleshooting

### Issue: Terraform Init Fails

```
Error: Failed to install provider
```

**Solution:**
```bash
# Clear cache and retry
rm -rf .terraform
terraform init
```

### Issue: Apply Takes Too Long

**Cause:** NAT Gateway creation takes 3-5 minutes each.

**Solution:** Wait patiently. For dev environments, use:
```hcl
single_nat_gateway = true  # Faster deploy, single NAT
```

### Issue: Cannot SSH to Bastion

**Solution:**
1. Check your IP is in `allowed_ssh_cidrs`
2. Verify security group rules:
```bash
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw bastion_security_group_id)
```

### Issue: Flow Logs Not Appearing

**Solution:** Flow logs can take up to 15 minutes to appear. Check:
```bash
aws logs describe-log-streams \
  --log-group-name $(terraform output -raw flow_logs_cloudwatch_log_group)
```

## Cost Breakdown

### Minimal Configuration (Dev)
- VPC: Free
- Subnets: Free
- Route Tables: Free
- Security Groups: Free
- Internet Gateway: Free
- NAT Gateway (1): ~$32/month
- VPC Endpoints (optional): ~$7/month each
- Flow Logs (S3): ~$0.50/GB
- **Total: ~$35-50/month**

### High Availability Configuration (Prod)
- NAT Gateway (2): ~$64/month
- VPC Endpoints (7): ~$50/month
- Flow Logs: Variable based on traffic
- **Total: ~$115-150/month**

**Pro tip:** VPC Endpoints save money on data transfer at scale. Break-even is typically 10+ GB/day transferred to AWS services.

## Cleanup

### Destroy All Resources

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy
```

Type `yes` when prompted.

**Warning:** This deletes everything including:
- VPC and all subnets
- NAT Gateways and Elastic IPs
- Security Groups and NACLs
- VPC Flow Logs (S3 bucket will remain due to objects)

### Manual Cleanup: Flow Logs S3 Bucket

```bash
# Get bucket name
BUCKET=$(terraform output -raw flow_logs_s3_bucket)

# Empty bucket
aws s3 rm s3://$BUCKET --recursive

# Delete bucket
aws s3 rb s3://$BUCKET
```

## Production Checklist

Before going to production:

- [ ] Set `single_nat_gateway = false` for high availability
- [ ] Increase `flow_logs_retention_days` to 30-90
- [ ] Enable VPC Endpoints for cost savings
- [ ] Set up CloudWatch alarms for security events
- [ ] Configure Terraform remote state in S3
- [ ] Enable MFA delete on state bucket
- [ ] Document your disaster recovery plan
- [ ] Test failover between availability zones
- [ ] Review all security group rules
- [ ] Set up automated backups
- [ ] Configure AWS Config for compliance
- [ ] Enable AWS GuardDuty for threat detection

## Getting Help

- **Terraform Errors:** Check `terraform validate` and `terraform fmt`
- **AWS Errors:** Use `aws sts get-caller-identity` to verify credentials
- **Networking Issues:** Check VPC Flow Logs for rejected connections
- **Documentation:** See `docs/architecture.md` and `docs/security-decisions.md`

## Resources

- [Full README](../README.md)
- [Architecture Guide](../docs/architecture.md)
- [Security Decisions](../docs/security-decisions.md)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
