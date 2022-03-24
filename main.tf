terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Steps for EC2 nginx
# Create a VPC
resource "aws_vpc" "nginx-vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create subnet for the vpc 
resource "aws_subnet" "subnet-public-1" {
  vpc_id                  = aws_vpc.nginx-vpc.id // Referencing the id of the VPC from above code block
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true" // Makes this a public subnet
  availability_zone       = "us-east-1"
  }

# Create Internet Gateway for the VPC
resource "aws_internet_gateway" "prod-igw" {
  vpc_id = aws_vpc.nginx-vpc.id
}

# Create route table for the VPC
resource "aws_route_table" "prod-public-crt" {
    vpc_id = aws_vpc.nginx-vpc.id
    route {
      cidr_block = "0.0.0.0/0"                      //associated subnet can reach everywhere
      gateway_id = aws_internet_gateway.prod-igw.id //CRT uses this IGW to reach internet
    }
    tags = {
      Name = "prod-public-crt"
    }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "prod-crta-public-subnet-1" {
    subnet_id      = aws_subnet.subnet-public-1.id
    route_table_id = aws_route_table.prod-public-crt.id
}

# Security Group to allow SSH and HTTP access
resource "aws_security_group" "ssh-allowed" {
    vpc_id = aws_vpc.nginx-vpc.id
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port   = 22
        protocol  = "tcp"
        cidr_blocks = ["0.0.0.0/0"] // Ideally best to use your machines IP. However if it is dynamic you will need to change this in the vpc every so often. 
    }
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# SSH public key
resource "aws_key_pair" "aws-key" {
    key_name   = "aws-key"
    public_key = file(var.PUBLIC_KEY_PATH)// Path is in the variables file
}

# Create EC2 with Nginx
resource "aws_instance" "nginx_server" {
    ami           = "ami-08d70e59c07c61a3a"
    instance_type = "t2.micro"
    tags = {
      Name = "nginx_server"
    }
    # VPC
    subnet_id = aws_subnet.subnet-public-1.id
    # Security Group
    vpc_security_group_ids = ["${aws_security_group.ssh-allowed.id}"]
    # the Public SSH key
    key_name = aws_key_pair.aws-key.id
    # nginx installation
    # storing the nginx.sh file in the EC2 instnace
    provisioner "file" {
      source      = "nginx.sh"
      destination = "/tmp/nginx.sh"
    }
    # Executing the nginx.sh file
    provisioner "remote-exec" {
      inline = [
        "chmod +x /tmp/nginx.sh",
        "sudo /tmp/nginx.sh"
      ]
    }# Setting up the ssh connection to install the nginx server
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file("${var.PRIVATE_KEY_PATH}")
    }
}

# Steps for EC2 apache web server
# Create a VPC
resource "aws_vpc" "apache_vpc" {
    cidr_block = var.vpc_cidr
  
    tags = {
      Name = "app-vpc"
    }
}

# Create internet gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.apache_vpc.id
  
    tags = {
      Name = "vpc_igw"
    }
}

# Create public subnet
resource "aws_subnet" "apache_public_subnet" {
    vpc_id            = aws_vpc.apache_vpc.id
    cidr_block        = var.public_subnet_cidr
    map_public_ip_on_launch = true
    availability_zone = "us-east-1"
  
    tags = {
      Name = "apache-public-subnet"
    }
}
  
# Crete route table
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.apache_vpc.id
  
    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
    }
  
    tags = {
      Name = "apache-public_rt"
    }
}
  
# Associate route table with public subnet
resource "aws_route_table_association" "public_rt_asso" {
    subnet_id      = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.public_rt.id
}

# Create EC2 apache web server
resource "aws_instance" "web" {
    ami             = "ami-005e54dee72cc1d00" 
    instance_type   = var.instance_type
    key_name        = var.instance_key
    subnet_id       = aws_subnet.apache_public_subnet.id
    security_groups = [aws_security_group.sg.id]
  
    user_data = <<-EOF
    #!/bin/bash
    echo "*** Installing apache2"
    sudo apt update -y
    sudo apt install apache2 -y
    echo "*** Completed Installing apache2"
    EOF
  
    tags = {
      Name = "web_instance"
    }
  
    volume_tags = {
      Name = "web_instance"
    } 
}

# Create Application Load Balancer
resource "aws_lb" "test-lb" {
    name               = "test-lb-tf"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.lb_sg.id]
    subnets            = [aws_subnet.subnet-public-1.id]
  
    enable_deletion_protection = true
  
    tags = {
      Environment = "production"
    }
  }  
  