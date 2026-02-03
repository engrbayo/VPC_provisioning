output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.main.arn
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "List of CIDR blocks of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "List of CIDR blocks of private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "data_subnet_ids" {
  description = "List of IDs of data tier subnets"
  value       = aws_subnet.data[*].id
}

output "data_subnet_cidrs" {
  description = "List of CIDR blocks of data tier subnets"
  value       = aws_subnet.data[*].cidr_block
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public Elastic IPs associated with NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = aws_route_table.private[*].id
}

output "data_route_table_id" {
  description = "ID of the data tier route table"
  value       = aws_route_table.data.id
}

output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group ID for application servers"
  value       = aws_security_group.app.id
}

output "database_security_group_id" {
  description = "Security group ID for database servers"
  value       = aws_security_group.database.id
}

output "bastion_security_group_id" {
  description = "Security group ID for bastion host"
  value       = aws_security_group.bastion.id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = var.enable_vpc_endpoints && contains(var.vpc_endpoint_services, "s3") ? aws_vpc_endpoint.s3[0].id : null
}

output "flow_logs_cloudwatch_log_group" {
  description = "CloudWatch Log Group for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}

output "flow_logs_s3_bucket" {
  description = "S3 Bucket for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_s3_bucket.flow_logs[0].id : null
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = data.aws_availability_zones.available.names
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

# Subnet information grouped by tier
output "subnet_info" {
  description = "Detailed subnet information grouped by tier"
  value = {
    public = {
      ids   = aws_subnet.public[*].id
      cidrs = aws_subnet.public[*].cidr_block
      azs   = aws_subnet.public[*].availability_zone
    }
    private = {
      ids   = aws_subnet.private[*].id
      cidrs = aws_subnet.private[*].cidr_block
      azs   = aws_subnet.private[*].availability_zone
    }
    data = {
      ids   = aws_subnet.data[*].id
      cidrs = aws_subnet.data[*].cidr_block
      azs   = aws_subnet.data[*].availability_zone
    }
  }
}

# Security group information
output "security_groups" {
  description = "Map of security group names to IDs"
  value = {
    alb           = aws_security_group.alb.id
    app           = aws_security_group.app.id
    database      = aws_security_group.database.id
    bastion       = aws_security_group.bastion.id
    vpc_endpoints = aws_security_group.vpc_endpoints.id
  }
}

# High-level summary for documentation
output "infrastructure_summary" {
  description = "High-level infrastructure summary"
  value = {
    vpc_id                   = aws_vpc.main.id
    vpc_cidr                 = aws_vpc.main.cidr_block
    availability_zones_count = length(data.aws_availability_zones.available.names)
    public_subnets_count     = length(aws_subnet.public)
    private_subnets_count    = length(aws_subnet.private)
    data_subnets_count       = length(aws_subnet.data)
    nat_gateways_count       = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
    flow_logs_enabled        = var.enable_flow_logs
    vpc_endpoints_enabled    = var.enable_vpc_endpoints
    environment              = var.environment
  }
}
