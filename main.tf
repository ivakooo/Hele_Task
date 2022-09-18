terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-west-2"
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = var.main_cidr_block

  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_cidr_blocks)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_cidr_blocks[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet_${count.index + 1}"
  }
}

resource "aws_security_group" "main_sg" {
  name        = "allow_connection"
  description = "Allow HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_http"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public_route"
  }
}

resource "aws_route_table_association" "public_route_association" {
  count          = length(var.public_cidr_blocks)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_lb" "front_end" {
  name               = "front-end-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.main_sg.id]
  subnets            = aws_subnet.public_subnets.*.id

  enable_deletion_protection = false

  tags = {
    Environment = "test"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.front_end.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }
}

resource "aws_lb_target_group" "front_end" {
  name     = "front-end-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "front_end" {
  count            = length(aws_subnet.public_subnets)
  target_group_arn = aws_lb_target_group.front_end.arn
  target_id        = aws_instance.front_end[count.index].id
  port             = 80
}


data "aws_ami" "amazon_linux_2" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_instance" "front_end" {
  count                       = length(aws_subnet.public_subnets)
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t2.nano"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public_subnets[count.index].id

  vpc_security_group_ids = [
    aws_security_group.main_sg.id,]
  
  user_data = <<-EOF
    #!/bin/bash
    sudo su
    yum update -y
    yum install -y httpd.x86_64
    systemctl start httpd.service
    systemctl enable httpd.service
    echo “Hello World from $(hostname -f)” > /var/www/html/index.html
        EOF

  tags = {
    Name = "HelloWorld_${count.index + 1}"
  }
}

resource "aws_efs_file_system" "efs" {
   creation_token   = "efs"
   performance_mode = "generalPurpose"
   throughput_mode  = "bursting"
   encrypted        = "true"
 tags               = {
     Name           = "EFS"
   }
 }


# # I am stuck here :( 

# Creating EFS file system
resource "aws_efs_file_system" "efs" {
creation_token = "my-efs"
tags = {
Name = "MyProduct"
  }
}
# Creating Mount target of EFS
resource "aws_efs_mount_target" "mount" {
file_system_id = aws_efs_file_system.efs.id
subnet_id      = aws_instance.web.subnet_id
security_groups = [aws_security_group.ec2_security_group.id]
}
# Creating Mount Point for EFS
resource "null_resource" "configure_nfs" {
depends_on = [aws_efs_mount_target.mount]
connection {
type     = "ssh"
user     = "ec2-user"
private_key = tls_private_key.my_key.private_key_pem
host     = aws_instance.web.public_ip
 }


resource "aws_db_instance" "default" {
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}

