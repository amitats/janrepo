data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.team}-${var.product}-${var.env}-vpc-${var.aws_region}"
  }
}

resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidrs" {
  count      = length(var.secondary_cidrs)
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.secondary_cidrs[count.index]
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  depends_on        = [aws_vpc_ipv4_cidr_block_association.secondary_cidrs]

  tags = {
    Name = "${var.team}-${var.product}-${var.env}-private-subnets-${var.aws_region}-${count.index}"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  depends_on        = [aws_vpc_ipv4_cidr_block_association.secondary_cidrs]

  tags = {
    Name = "${var.team}-${var.product}-${var.env}-public-subnets-${var.aws_region}-${count.index}"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.team}-${var.product}-${var.env}-internet-gateway-${var.aws_region}"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name    = "${var.team}-${var.product}-${var.env}-public-route-table-${var.aws_region}"
    Network = upper("${var.product} PublicRouteTable")
  }
}

resource "aws_route_table" "private_route_tables" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name    = "${var.team}-${var.product}-${var.env}-private-route-tables-${var.aws_region}-${count.index}"
    Network = upper("${var.product} PrivateRouteTable-${count.index}")
  }
}

resource "aws_eip" "nat_gateway_eips" {
  # vpc = true
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eips.id
  subnet_id     = aws_subnet.public_subnets[0].id
  depends_on    = [aws_internet_gateway.internet_gateway]
  tags = {
    Name = "${var.team}-${var.product}-${var.env}-nat-gateway-${var.aws_region}"
  }
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_route" "private_routes" {
  count                  = length(var.private_subnet_cidrs)
  route_table_id         = aws_route_table.private_route_tables[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
  depends_on = [ aws_route_table.private_route_tables ]
}

resource "aws_route_table_association" "public_subnet_route_table_associations" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_route_table_association" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_tables[count.index].id
  depends_on = [aws_subnet.private_subnets, aws_route_table.private_route_tables, aws_route.private_routes]
}
