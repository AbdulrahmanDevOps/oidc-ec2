# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Get first subnet
data "aws_subnet" "selected" {
  id = data.aws_subnets.default.ids[0]
}

# Security Group
resource "aws_security_group" "web" {
  name        = "${var.instance_name}-sg"
  description = "Allow web traffic"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr
  }

  # HTTP access
  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami           = "ami-0bb84b8ffd87024d8"  # Amazon Linux 2023
  instance_type = var.instance_type
  
  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = [aws_security_group.web.id]
  
  associate_public_ip_address = true

  # Install web server
  user_data = <<-EOF
              #!/bin/bash
              sudo dnf update -y
              sudo dnf install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              sudo echo "<h1>Deployed via GitHub OIDC!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = var.instance_name
  }
}