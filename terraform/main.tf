# Observability host on AWS Free Tier: one t3.micro EC2 running the
# Docker Compose stack. No paid resources: t3.micro + default VPC only.
# Apply only with explicit approval (cost rule).

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "observability" {
  name        = "observability-stack-sg"
  description = "Allow SSH from admin CIDR + Grafana/Prometheus from anywhere"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH (restricted)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "Grafana UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "Prometheus UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "observability-stack-sg" }
}

resource "aws_instance" "observability" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.observability.id]
  key_name               = var.key_name != "" ? var.key_name : null

  user_data = templatefile("${path.module}/user_data.sh", {
    grafana_admin_password = var.grafana_admin_password
    repo_url               = "https://github.com/giriboinar/devops-observability-stack.git"
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "observability-stack" }
}
