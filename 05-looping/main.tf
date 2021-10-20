locals {
  # Determine number of bits required for subnets: 2 if we need db subnets; 1 otherwise
  subnet_type_bits = var.include_db ? 2 : 1
  # Determine number of bits required for az's: half the number of az's
  az_cidr_bits = ceil(var.az_count / 2)

  # Generate CIDR blocks
  subnet_type_bits_list = [local.subnet_type_bits, local.subnet_type_bits, local.subnet_type_bits]
  az_cidr_bits_list     = [local.az_cidr_bits, local.az_cidr_bits, local.az_cidr_bits]
  cidr_blocks = [for cidr_block in cidrsubnets(var.vpc_cidr, slice(local.subnet_type_bits_list, 0, var.include_db ? 3 : 2)...)
  : cidrsubnets(cidr_block, slice(local.az_cidr_bits_list, 0, var.az_count)...)]

  #availability_zone_suffixes = ["a", "b", "c"]
  availability_zone_suffixes = ["a", "b"]
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = {}
}

resource "aws_subnet" "public" {
  count = length(local.cidr_blocks[0])

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.cidr_blocks[0][count.index]
  availability_zone       = "${var.region}${local.availability_zone_suffixes[count.index % length(local.availability_zone_suffixes)]}"
  map_public_ip_on_launch = true
  tags                    = {
    Name = "${var.owner}-public-subnet-${local.availability_zone_suffixes[count.index % length(local.availability_zone_suffixes)]}${floor(count.index / length(local.availability_zone_suffixes) + 1)}"
  }
}

resource "aws_subnet" "private" {
  count = length(local.cidr_blocks[1])

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.cidr_blocks[1][count.index]
  availability_zone = "${var.region}${local.availability_zone_suffixes[count.index % length(local.availability_zone_suffixes)]}"
  tags                    = {
    Name = "${var.owner}-private-subnet-${local.availability_zone_suffixes[count.index % length(local.availability_zone_suffixes)]}${floor(count.index / length(local.availability_zone_suffixes) + 1)}"
  }
}

resource "aws_subnet" "database" {
  count = var.include_db ? length(local.cidr_blocks[2]) : 0

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.cidr_blocks[2][count.index]
  availability_zone = "${var.region}${local.availability_zone_suffixes[count.index % length(local.availability_zone_suffixes)]}"
  tags                    = {
    Name = "${var.owner}-database-subnet-${local.availability_zone_suffixes[count.index % length(local.availability_zone_suffixes)]}${floor(count.index / length(local.availability_zone_suffixes) + 1)}"
  }
}