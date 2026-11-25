terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"

    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = "access_key"
  secret_key = "secret key"
}

# creating a vpc
resource "aws_vpc" "prod-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "procuction"
  }
}

# creating an internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "terra-gw"
  }
}

# creating a route table


resource "aws_route_table" "produ-terra" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "example"
  }
}

#creating subnet
resource "aws_subnet" "produc-terra-subnet" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = var.subnet_cidr_prefix
  availability_zone = "us-east-1a"
  tags = {
    Name = "prod-subnet"
  }

}

#Associate subnet with route table
resource "aws_route_table_association" "example" {
  subnet_id      = aws_subnet.produc-terra-subnet.id
  route_table_id = aws_route_table.produ-terra.id
}

# creating  security groups

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic "
  vpc_id      = aws_vpc.prod-vpc.id

  tags = {
    Name = "prod_security_group"
  }
}


resource "aws_vpc_security_group_ingress_rule" "HTTPS_ALLOW" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
resource "aws_vpc_security_group_ingress_rule" "HTTP_ALLOW" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "SSH_ALLOW" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "34.236.162.110/32"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}



resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
  tags = {
    Names = "Allow_web_ssh "
  }
}
output "sever_private_ip" {
  value = aws_network_interface.web-server-NIC.private_ip

}

# CREATING A NETWORK INTERFACE

resource "aws_network_interface" "web-server-NIC" {
  subnet_id       = aws_subnet.produc-terra-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
  #attachment {
  # instance     = aws_instance.produ_server.id
  #device_index = 1
  #}
}



# creating a public ip and an elastic ip
resource "aws_eip" "one" {
  domain = "vpc"

  network_interface         = aws_network_interface.web-server-NIC.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}
output "server_ip" {
  value = aws_eip.one.public_ip

}
variable "subnet_cidr_prefix" {
  description = "cidr block value"
  type        = string

}
#Creatign an ec2 server


resource "aws_instance" "produ_server" {
  ami               = "ami-096ef200a877f36af"
  instance_type     = "t3.micro"
  availability_zone = "us-east-1a"

  key_name = "prod_k"

  primary_network_interface {

    network_interface_id = aws_network_interface.web-server-NIC.id
  }







  user_data = <<-EOF
             #!/bin/bash
             sudo dnf update -y
             sudo dnf install httpd -y
             sudo systemctl start httpd
             echo"Hi, your very first webserver> /var/www/html/index.html"
             EOF

  tags = {
    Name = "prod-server"
  }
}
