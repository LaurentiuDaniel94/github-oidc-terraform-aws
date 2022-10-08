data "aws_availability_zones" "available" {}

locals {
  azs = data.aws_availability_zones.available.names
}

resource "random_id" "random" {
  byte_length = 2
}

resource "aws_vpc" "lvu_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    "Name" = "lvu_VPC-${random_id.random.dec}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_internet_gateway" "lvu_igw" {
  vpc_id = aws_vpc.lvu_vpc.id
  tags = {
    "Name" = "lvu-igw-${random_id.random.dec}"
  }
}

resource "aws_route_table" "lvu_public_rt" {
  vpc_id = aws_vpc.lvu_vpc.id
  tags = {
    "Name" = "lvu-public"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.lvu_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lvu_igw.id
}

resource "aws_default_route_table" "lvu-_private_rt" {
  default_route_table_id = aws_vpc.lvu_vpc.default_route_table_id
  tags = {
    "Name" = "private-rt"
  }
}

resource "aws_subnet" "lvu_public_subnet" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.lvu_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = local.azs[count.index]
  tags = {
    "Name" = "Public-Subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "lvu_private_subnet" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.lvu_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, length(local.azs) + count.index)
  map_public_ip_on_launch = false
  availability_zone       = local.azs[count.index]
  tags = {
    "Name" = "Private_subnet-${count.index + 1}"
  }
}

resource "aws_route_table_association" "lvu_public_asocc" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.lvu_public_subnet[count.index].id
  route_table_id = aws_route_table.lvu_public_rt.id
}

# Create security group and rules
resource "aws_security_group" "lvu-sg" {
  name        = "public-sg"
  description = "Security Group for Public Instances"
  vpc_id      = aws_vpc.lvu_vpc.id
}

resource "aws_security_group_rule" "ingress_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = var.access_ip
  security_group_id = aws_security_group.lvu-sg.id
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lvu-sg.id
}

