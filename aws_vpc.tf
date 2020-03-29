# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.vpc_name }
}

resource "aws_subnet" "public" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { "Name" = "Public-${split("-", data.aws_availability_zones.available.names[count.index])[2]}" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "private" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 4, count.index + 6)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { "Name" = "Private-${split("-", data.aws_availability_zones.available.names[count.index])[2]}" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "database" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 4, count.index + 12)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { "Name" = "Database-${split("-", data.aws_availability_zones.available.names[count.index])[2]}" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_internet_gateway" "internet" {
  vpc_id = aws_vpc.vpc.id
  tags   = { "Name" = "${var.app_name}-igw" }
}

/* Public */
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags   = { "Name" = "public-route-table" }
}

resource "aws_route_table_association" "public" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.internet.id
  destination_cidr_block = "0.0.0.0/0"
}

/* Private */
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags   = { "Name" = "private-route-table" }
}

resource "aws_route_table_association" "private" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
  destination_cidr_block = "0.0.0.0/0"
}

/* Database */
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.vpc.id
  tags   = { "Name" = "database-route-table" }
}

resource "aws_route_table_association" "database" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

resource "aws_route" "database_default" {
  route_table_id         = aws_route_table.database.id
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
  destination_cidr_block = "0.0.0.0/0"
}
