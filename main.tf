provider "aws" {
  region = "us-west-2"
}


terraform {
  backend "remote" {
    organization = "YuanHuang" # Replace with your Terraform Cloud organization name

    workspaces {
      name = "v2ray" # Replace with your workspace name
    }
  }

  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "open" {
  name        = "open-sg"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_key_pair" "deployer" {
    key_name   = "your-key-pair-name" # Replace with your desired key pair name
    public_key = file("~/.ssh/id_rsa.pub") # Path to your public key file
}

resource "aws_iam_role" "ssm_role" {
    name = "ec2-ssm-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
    role       = aws_iam_role.ssm_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
    name = "ec2-ssm-instance-profile"
    role = aws_iam_role.ssm_role.name
}

resource "aws_instance" "linux_with_ssm" {
    ami                         = "ami-0418306302097dbff"
    instance_type               = "t2.micro"
    subnet_id                   = aws_subnet.main.id
    vpc_security_group_ids      = [aws_security_group.open.id]
    associate_public_ip_address = true
    key_name                    = aws_key_pair.deployer.key_name
    iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

    tags = {
        Name = "free-tier-linux-ssm"
    }
}