# Application Load Balancer Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-sg-"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-alb-sg-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Ingress - HTTPS from internet
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet"

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-https-from-internet"
  }
}

# ALB Ingress - HTTP (for redirect to HTTPS)
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet (redirect to HTTPS)"

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-http-from-internet"
  }
}

# ALB Egress - All outbound traffic
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-all-outbound"
  }
}

# Application Server Security Group
resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-app-sg-"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-app-sg-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# App Ingress - Application port from ALB only
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id = aws_security_group.app.id
  description       = "Application traffic from ALB"

  ip_protocol                  = "tcp"
  from_port                    = var.app_server_port
  to_port                      = var.app_server_port
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Name = "allow-app-from-alb"
  }
}

# App Ingress - SSH from bastion only
resource "aws_vpc_security_group_ingress_rule" "app_ssh_from_bastion" {
  security_group_id = aws_security_group.app.id
  description       = "SSH from bastion"

  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id

  tags = {
    Name = "allow-ssh-from-bastion"
  }
}

# App Egress - All outbound traffic
resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-all-outbound"
  }
}

# Database Security Group
resource "aws_security_group" "database" {
  name_prefix = "${var.project_name}-db-sg-"
  description = "Security group for database servers"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-db-sg-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Database Ingress - PostgreSQL from app servers only
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id = aws_security_group.database.id
  description       = "PostgreSQL from application servers"

  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
  referenced_security_group_id = aws_security_group.app.id

  tags = {
    Name = "allow-postgres-from-app"
  }
}

# Database Ingress - PostgreSQL from bastion for maintenance
resource "aws_vpc_security_group_ingress_rule" "db_from_bastion" {
  security_group_id = aws_security_group.database.id
  description       = "PostgreSQL from bastion for maintenance"

  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
  referenced_security_group_id = aws_security_group.bastion.id

  tags = {
    Name = "allow-postgres-from-bastion"
  }
}

# Database Egress - Restricted to VPC only
resource "aws_vpc_security_group_egress_rule" "db_vpc_only" {
  security_group_id = aws_security_group.database.id
  description       = "Allow outbound to VPC only"

  ip_protocol = "-1"
  cidr_ipv4   = var.vpc_cidr

  tags = {
    Name = "allow-vpc-outbound"
  }
}

# Bastion Host Security Group
resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-bastion-sg-"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-bastion-sg-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Bastion Ingress - SSH from allowed CIDRs only
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  count = length(var.allowed_ssh_cidrs) > 0 ? 1 : 0

  security_group_id = aws_security_group.bastion.id
  description       = "SSH from allowed IP addresses"

  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_ipv4   = var.allowed_ssh_cidrs[0]

  tags = {
    Name = "allow-ssh-from-allowed-ips"
  }
}

# Bastion Egress - All outbound traffic
resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-all-outbound"
  }
}

# VPC Endpoint Security Group
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-vpce-sg-"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-vpce-sg-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# VPC Endpoint Ingress - HTTPS from VPC
resource "aws_vpc_security_group_ingress_rule" "vpce_https" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "HTTPS from VPC"

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = var.vpc_cidr

  tags = {
    Name = "allow-https-from-vpc"
  }
}

# VPC Endpoint Egress - VPC only (endpoints only communicate within the VPC)
resource "aws_vpc_security_group_egress_rule" "vpce_all" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "Allow outbound to VPC only"

  ip_protocol = "-1"
  cidr_ipv4   = var.vpc_cidr

  tags = {
    Name = "allow-vpc-outbound"
  }
}
