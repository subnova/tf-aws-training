data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

#
# VPC
#
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.owner}-vpc"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnets("10.0.0.0/16", 8, 8, 8, 8)[count.index + length(aws_subnet.private)]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.owner}-public-subnet-${substr(data.aws_availability_zones.available.names[count.index], length(data.aws_availability_zones.available.names[count.index]) - 1, 1)}"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "${var.owner}-public"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnets("10.0.0.0/16", 8, 8)[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.owner}-private-subnet-${substr(data.aws_availability_zones.available.names[count.index], length(data.aws_availability_zones.available.names[count.index]) - 1, 1)}"
  }
}

resource "aws_eip" "nat_gateway" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [
    aws_internet_gateway.internet_gateway
  ]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "${var.owner}-private"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

#
# Instance
#

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_iam_role" "instance_role" {
  name = "${var.owner}-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_security_group" "outbound_to_internet" {
  name        = "${var.owner}-outbound-internet"
  description = "Allow outbound traffic to Internet"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Outbound to Internet"
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.owner}-profile"
  role = aws_iam_role.instance_role.name
  tags = {}
}

resource "aws_launch_template" "instance_template" {
  name          = "${var.owner}-instance-template"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }
  vpc_security_group_ids = [
    aws_security_group.outbound_to_internet.id
  ]
}

resource "aws_autoscaling_group" "instance_group" {
  name                = "${var.owner}-instance-group"
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1
  vpc_zone_identifier = aws_subnet.private.*.id

  launch_template {
    id      = aws_launch_template.instance_template.id
    version = aws_launch_template.instance_template.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  tag {
    key                 = "Name"
    value               = "${var.owner}-instance-group"
    propagate_at_launch = true
  }
}