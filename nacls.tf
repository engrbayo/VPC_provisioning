# Public Subnet Network ACL
resource "aws_network_acl" "public" {
  count = var.enable_nacls ? 1 : 0

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-public-nacl-${var.environment}"
    Tier = "Public"
  }
}

# Public NACL - Inbound Rules
resource "aws_network_acl_rule" "public_inbound_http" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
  egress         = false
}

resource "aws_network_acl_rule" "public_inbound_https" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
  egress         = false
}

resource "aws_network_acl_rule" "public_inbound_ssh" {
  count = var.enable_nacls && length(var.allowed_ssh_cidrs) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 120
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.allowed_ssh_cidrs[0]
  from_port      = 22
  to_port        = 22
  egress         = false
}

resource "aws_network_acl_rule" "public_inbound_ephemeral" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 140
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
  egress         = false
}

# Public NACL - Outbound Rules
resource "aws_network_acl_rule" "public_outbound_http" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
  egress         = true
}

resource "aws_network_acl_rule" "public_outbound_https" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
  egress         = true
}

resource "aws_network_acl_rule" "public_outbound_ephemeral" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 140
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
  egress         = true
}

resource "aws_network_acl_rule" "public_outbound_vpc" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 150
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  egress         = true
}

# Private Subnet Network ACL
resource "aws_network_acl" "private" {
  count = var.enable_nacls ? 1 : 0

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-private-nacl-${var.environment}"
    Tier = "Private"
  }
}

# Private NACL - Inbound Rules
resource "aws_network_acl_rule" "private_inbound_vpc" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.private[0].id
  rule_number    = 100
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  egress         = false
}

resource "aws_network_acl_rule" "private_inbound_ephemeral" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.private[0].id
  rule_number    = 140
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
  egress         = false
}

# Private NACL - Outbound Rules
resource "aws_network_acl_rule" "private_outbound_http" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.private[0].id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
  egress         = true
}

resource "aws_network_acl_rule" "private_outbound_https" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.private[0].id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
  egress         = true
}

resource "aws_network_acl_rule" "private_outbound_vpc" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.private[0].id
  rule_number    = 120
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  egress         = true
}

resource "aws_network_acl_rule" "private_outbound_ephemeral" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.private[0].id
  rule_number    = 140
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
  egress         = true
}

# Data Subnet Network ACL (Most restrictive)
resource "aws_network_acl" "data" {
  count = var.enable_nacls ? 1 : 0

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.data[*].id

  tags = {
    Name = "${var.project_name}-data-nacl-${var.environment}"
    Tier = "Data"
  }
}

# Data NACL - Inbound Rules (VPC only)
resource "aws_network_acl_rule" "data_inbound_vpc" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.data[0].id
  rule_number    = 100
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  egress         = false
}

# Data NACL - Outbound Rules (VPC only)
resource "aws_network_acl_rule" "data_outbound_vpc" {
  count = var.enable_nacls ? 1 : 0

  network_acl_id = aws_network_acl.data[0].id
  rule_number    = 100
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  egress         = true
}
