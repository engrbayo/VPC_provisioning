# VPC Endpoints for AWS Services (reduces data transfer costs and improves security)

# S3 Gateway Endpoint (no cost)
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_vpc_endpoints && contains(var.vpc_endpoint_services, "s3") ? 1 : 0

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    [aws_route_table.data.id]
  )

  tags = {
    Name = "${var.project_name}-s3-endpoint-${var.environment}"
  }
}

# DynamoDB Gateway Endpoint (no cost)
resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_vpc_endpoints && contains(var.vpc_endpoint_services, "dynamodb") ? 1 : 0

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    [aws_route_table.data.id]
  )

  tags = {
    Name = "${var.project_name}-dynamodb-endpoint-${var.environment}"
  }
}

# EC2 Interface Endpoint
resource "aws_vpc_endpoint" "ec2" {
  count = var.enable_vpc_endpoints && contains(var.vpc_endpoint_services, "ec2") ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${var.project_name}-ec2-endpoint-${var.environment}"
  }
}

# ECR API Interface Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  count = var.enable_vpc_endpoints && contains(var.vpc_endpoint_services, "ecr.api") ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${var.project_name}-ecr-api-endpoint-${var.environment}"
  }
}

# ECR Docker Interface Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.enable_vpc_endpoints && contains(var.vpc_endpoint_services, "ecr.dkr") ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${var.project_name}-ecr-dkr-endpoint-${var.environment}"
  }
}

# CloudWatch Logs Interface Endpoint
resource "aws_vpc_endpoint" "logs" {
  count = var.enable_vpc_endpoints && contains(var.vpc_endpoint_services, "logs") ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${var.project_name}-logs-endpoint-${var.environment}"
  }
}

# Secrets Manager Interface Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  count = var.enable_vpc_endpoints && contains(var.vpc_endpoint_services, "secretsmanager") ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${var.project_name}-secretsmanager-endpoint-${var.environment}"
  }
}

# SSM Interface Endpoint
resource "aws_vpc_endpoint" "ssm" {
  count = var.enable_vpc_endpoints && contains(var.vpc_endpoint_services, "ssm") ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${var.project_name}-ssm-endpoint-${var.environment}"
  }
}

# SSM Messages Interface Endpoint (for Session Manager)
resource "aws_vpc_endpoint" "ssmmessages" {
  count = var.enable_vpc_endpoints && contains(var.vpc_endpoint_services, "ssm") ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${var.project_name}-ssmmessages-endpoint-${var.environment}"
  }
}

# EC2 Messages Interface Endpoint (for Session Manager)
resource "aws_vpc_endpoint" "ec2messages" {
  count = var.enable_vpc_endpoints && contains(var.vpc_endpoint_services, "ssm") ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${var.project_name}-ec2messages-endpoint-${var.environment}"
  }
}
