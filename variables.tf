variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "secure-vpc"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner or team responsible for resources"
  type        = string
  default     = "infrastructure-team"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "data_subnet_cidrs" {
  description = "CIDR blocks for data tier subnets (no internet access)"
  type        = list(string)
  default     = ["10.0.100.0/24", "10.0.200.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway instead of one per AZ (cost savings for dev)"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention period for Flow Logs in CloudWatch (days)"
  type        = number
  default     = 7
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC Endpoints for AWS services"
  type        = bool
  default     = true
}

variable "vpc_endpoint_services" {
  description = "List of AWS services to create VPC endpoints for"
  type        = list(string)
  default = [
    "s3",
    "ec2",
    "ecr.api",
    "ecr.dkr",
    "logs",
    "secretsmanager",
    "ssm"
  ]
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to bastion (use your specific IP)"
  type        = list(string)
  default     = [] # Empty by default for security - must be explicitly set
}

variable "enable_nacls" {
  description = "Enable custom Network ACLs"
  type        = bool
  default     = true
}

variable "app_server_port" {
  description = "Port for application servers"
  type        = number
  default     = 8080
}

variable "database_port" {
  description = "Port for database servers"
  type        = number
  default     = 5432
}
