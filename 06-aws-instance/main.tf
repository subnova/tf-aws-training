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

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnets("10.0.0.0/16", 8, 8)[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.owner}-private-subnet-${substr(data.aws_availability_zones.available.names[count.index], length(data.aws_availability_zones.available.names[count.index]) - 1, 1)}"
  }
}

resource "aws_security_group" "inbound_tls_from_vpc" {
  name        = "${var.owner}-inbound-tls-from-vpc"
  description = "Allow inbound TLS access from VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {}
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.inbound_tls_from_vpc.id
  ]

  private_dns_enabled = true

  subnet_ids = aws_subnet.private.*.id

  tags = {
    Name = "${var.owner}-aws-ssm"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.inbound_tls_from_vpc.id
  ]

  private_dns_enabled = true

  subnet_ids = aws_subnet.private.*.id

  tags = {
    Name = "${var.owner}-aws-ec2messages"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.inbound_tls_from_vpc.id
  ]

  private_dns_enabled = true

  subnet_ids = aws_subnet.private.*.id

  tags = {
    Name = "${var.owner}-aws-ssmmessages"
  }
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

resource "aws_security_group" "outbound_to_vpc" {
  name        = "${var.owner}-outbound-vpc"
  description = "Allow outbound traffic to VPC"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Outbound to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.owner}-profile"
  role = aws_iam_role.instance_role.name
  tags = {}
}

resource "aws_instance" "instance" {
  instance_type        = "t3.micro"
  ami                  = data.aws_ami.ubuntu.id
  subnet_id            = aws_subnet.private[0].id
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  security_groups = [
    aws_security_group.outbound_to_vpc.id
  ]

  tags = {
    Name = "${var.owner}-instance"
  }
}
