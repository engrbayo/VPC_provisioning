# Secure VPC Infrastructure with Terraform

This repository contains Terraform code to deploy a production-ready, highly available VPC infrastructure on AWS following security best practices and the principle of defense in depth.

## Architecture Overview

The infrastructure implements a three-tier network architecture:

- **Public Tier**: Internet-facing resources (ALB, NAT Gateway, Bastion)
- **Private Tier**: Application servers with outbound internet access via NAT
- **Data Tier**: Databases with no internet access whatsoever

### Key Features

✅ Multi-AZ deployment for high availability  
✅ Defense in depth with Security Groups + Network ACLs  
✅ VPC Flow Logs to CloudWatch and S3 for visibility  
✅ VPC Endpoints to reduce data transfer costs  
✅ Least-privilege security group rules  
✅ Isolated data tier with no internet route  
✅ NAT Gateway for private subnet outbound access  
✅ Comprehensive tagging strategy  

## Network Design

```
VPC: 10.0.0.0/16

├── Public Subnets (2 AZs)
│   ├── 10.0.1.0/24 (us-east-1a)
│   └── 10.0.2.0/24 (us-east-1b)
│
├── Private Subnets (2 AZs)
│   ├── 10.0.10.0/24 (us-east-1a)
│   └── 10.0.20.0/24 (us-east-1b)
│
└── Data Subnets (2 AZs)
    ├── 10.0.100.0/24 (us-east-1a)
    └── 10.0.200.0/24 (us-east-1b)
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- AWS Account with appropriate IAM permissions

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd 02-vpc-infrastructure-as-code
```

### 2. Configure Variables

Edit `terraform/terraform.tfvars` to customize your deployment:

```hcl
# IMPORTANT: Set your IP address for SSH access
allowed_ssh_cidrs = ["YOUR.IP.ADDRESS/32"]

# Set to true for dev to save costs
single_nat_gateway = true

# Adjust retention for your needs
flow_logs_retention_days = 7
```

### 3. Initialize Terraform

```bash
cd terraform
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm deployment.

### 6. View Outputs

```bash
terraform output
```

## Project Structure

```
02-vpc-infrastructure-as-code/
├── README.md                    # This file
├── terraform/
│   ├── main.tf                  # Provider and backend configuration
│   ├── vpc.tf                   # VPC and subnet resources
│   ├── routing.tf               # Route tables and associations
│   ├── nat.tf                   # NAT Gateway configuration
│   ├── security_groups.tf       # Security group definitions
│   ├── nacls.tf                 # Network ACL rules
│   ├── endpoints.tf             # VPC Endpoints for AWS services
│   ├── flow_logs.tf             # VPC Flow Logs configuration
│   ├── variables.tf             # Input variable definitions
│   ├── outputs.tf               # Output values
│   └── terraform.tfvars         # Variable values (customize this)
└── docs/
    ├── architecture.md          # Detailed architecture explanation
    └── security-decisions.md    # Security design rationale
```

## Cost Optimization

### Development Environment

For non-production environments, consider these cost-saving options:

```hcl
# Use single NAT Gateway (~$32/month instead of ~$64/month)
single_nat_gateway = true

# Disable VPC Endpoints if not needed
enable_vpc_endpoints = false

# Reduce Flow Logs retention
flow_logs_retention_days = 7
```

### Production Environment

For production, prioritize availability:

```hcl
# Use NAT Gateway per AZ for redundancy
single_nat_gateway = false

# Enable VPC Endpoints to reduce data transfer costs
enable_vpc_endpoints = true

# Increase retention for compliance
flow_logs_retention_days = 90
```

## Security Features

### Layer 1: Network ACLs (Subnet-level)
- Stateless filtering
- Default deny with explicit allows
- Rule-based priority system

### Layer 2: Security Groups (Instance-level)
- Stateful filtering
- Security group referencing
- Least-privilege access

### Layer 3: Routing Isolation
- Data tier has NO internet route
- Private tier uses NAT for outbound only
- Public tier restricted to load balancers

### Layer 4: VPC Flow Logs
- All traffic metadata captured
- CloudWatch for real-time monitoring
- S3 for long-term analysis

## VPC Flow Logs Analysis

### Query Flow Logs in CloudWatch Logs Insights

```sql
fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, protocol, action
| filter action = "REJECT"
| stats count() by srcAddr, dstAddr, dstPort
| sort count desc
| limit 20
```

### Analyze with Amazon Athena

VPC Flow Logs are stored in S3 in Parquet format for efficient querying:

```sql
SELECT srcaddr, dstaddr, dstport, protocol, action, COUNT(*) as count
FROM vpc_flow_logs
WHERE action = 'REJECT'
  AND day = '2024/01/15'
GROUP BY srcaddr, dstaddr, dstport, protocol, action
ORDER BY count DESC
LIMIT 100;
```

## Common Tasks

### Add SSH Access for New IP

```hcl
# In terraform.tfvars
allowed_ssh_cidrs = ["203.0.113.0/32", "198.51.100.0/32"]
```

```bash
terraform apply
```

### Enable Additional VPC Endpoints

```hcl
# In terraform.tfvars
vpc_endpoint_services = [
  "s3",
  "ec2",
  "ecr.api",
  "ecr.dkr",
  "logs",
  "secretsmanager",
  "ssm",
  "rds"  # Add RDS endpoint
]
```

### View NAT Gateway IPs (for allowlisting)

```bash
terraform output nat_gateway_public_ips
```

## Troubleshooting

### Issue: Cannot SSH to Bastion

**Solution**: Check that your IP is in `allowed_ssh_cidrs` and security group rules are correct:

```bash
terraform output bastion_security_group_id
aws ec2 describe-security-groups --group-ids <sg-id>
```

### Issue: Private Instances Can't Reach Internet

**Solution**: Verify NAT Gateway and route tables:

```bash
terraform output nat_gateway_ids
aws ec2 describe-route-tables --route-table-ids <rt-id>
```

### Issue: High Data Transfer Costs

**Solution**: Enable VPC Endpoints for frequently accessed AWS services:

```hcl
enable_vpc_endpoints = true
```

## Clean Up

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all resources including VPC Flow Logs in S3 (after lifecycle policy expiration).

## Next Steps

After deploying the VPC:

1. Deploy application servers in private subnets
2. Deploy RDS databases in data subnets
3. Configure Application Load Balancer in public subnets
4. Set up bastion host or use AWS Systems Manager Session Manager
5. Configure CloudWatch alarms for VPC Flow Logs anomalies

## Best Practices Implemented

✅ **Multi-AZ Deployment**: Resources spread across availability zones  
✅ **Least Privilege**: Security groups reference each other, not CIDR blocks  
✅ **Defense in Depth**: Multiple layers of security controls  
✅ **Visibility**: Comprehensive logging with VPC Flow Logs  
✅ **Cost Optimization**: VPC Endpoints reduce data transfer costs  
✅ **Infrastructure as Code**: Version-controlled, repeatable deployments  
✅ **Secure by Default**: Data tier has no internet access  

## References

- [AWS VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## License

MIT

## Contributing

Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.
