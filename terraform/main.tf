locals {
  sles_sap_ami = "ami-099afc29551c4b139"
}

# --- VPC and Networking ---

resource "aws_vpc" "hana" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "hana-vpc" }
}

resource "aws_subnet" "primary" {
  vpc_id            = aws_vpc.hana.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags = { Name = "hana-primary-subnet" }
}

resource "aws_subnet" "secondary" {
  vpc_id            = aws_vpc.hana.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  tags = { Name = "hana-secondary-subnet" }
}

resource "aws_internet_gateway" "hana" {
  vpc_id = aws_vpc.hana.id
  tags   = { Name = "hana-igw" }
}

resource "aws_route_table" "hana" {
  vpc_id = aws_vpc.hana.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hana.id
  }
  tags = { Name = "hana-rt" }
}

resource "aws_route_table_association" "primary" {
  subnet_id      = aws_subnet.primary.id
  route_table_id = aws_route_table.hana.id
}

resource "aws_route_table_association" "secondary" {
  subnet_id      = aws_subnet.secondary.id
  route_table_id = aws_route_table.hana.id
}

# --- Private Route 53 Zone ---

resource "aws_route53_zone" "hana" {
  name = var.private_zone_name
  vpc {
    vpc_id = aws_vpc.hana.id
  }
  tags = { Name = "hana-private-zone" }
}

resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.hana.zone_id
  name    = "hana-primary.${var.private_zone_name}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.hana_primary.private_ip]
}

resource "aws_route53_record" "secondary" {
  zone_id = aws_route53_zone.hana.zone_id
  name    = "hana-secondary.${var.private_zone_name}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.hana_secondary.private_ip]
}

# --- IAM ---

resource "aws_iam_role" "hana_s3" {
  name = "hana-s3-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "hana_s3" {
  name = "hana-s3-read"
  role = aws_iam_role.hana_s3.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::${var.hana_media_bucket}",
        "arn:aws:s3:::${var.hana_media_bucket}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "hana_s3" {
  name = "hana-s3-profile"
  role = aws_iam_role.hana_s3.name
}

# --- Security Groups ---

resource "aws_security_group" "hana" {
  name        = "hana-sg"
  description = "SSH + internal VPC for HANA HSR"
  vpc_id      = aws_vpc.hana.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "All internal VPC traffic (HSR)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hana-sg" }
}

# --- EC2 Instances ---

resource "aws_instance" "hana_primary" {
  ami                         = local.sles_sap_ami
  instance_type               = "r5.xlarge"
  key_name                    = var.key_pair_name
  subnet_id                   = aws_subnet.primary.id
  vpc_security_group_ids      = [aws_security_group.hana.id]
  iam_instance_profile        = aws_iam_instance_profile.hana_s3.name
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 100
  }

  tags = { Name = "hana-primary" }
}

resource "aws_instance" "hana_secondary" {
  ami                         = local.sles_sap_ami
  instance_type               = "r5.xlarge"
  key_name                    = var.key_pair_name
  subnet_id                   = aws_subnet.secondary.id
  vpc_security_group_ids      = [aws_security_group.hana.id]
  iam_instance_profile        = aws_iam_instance_profile.hana_s3.name
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 100
  }

  tags = { Name = "hana-secondary" }
}
