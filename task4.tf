provider "aws" {
  region = "ap-south-1"
  profile = "pintu"
}


resource "aws_vpc" "AjVpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "AjVpc"
  }
}


resource "aws_subnet" "AJsubnet-1a" {
  vpc_id     = aws_vpc.AjVpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
  depends_on = [
    aws_vpc.AjVpc,
  ]

  tags = {
    Name = "AJsubnet-1a"
  }
}


resource "aws_subnet" "AJsubnet-1b" {
  vpc_id     = aws_vpc.AjVpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
  depends_on = [
    aws_vpc.AjVpc,
  ]

  tags = {
    Name = "AJsubnet-1b"
  }
}



resource "aws_internet_gateway" "AJigw" {
  vpc_id = aws_vpc.AjVpc.id
  depends_on = [
    aws_vpc.AjVpc,
  ]

  tags = {
    Name = "AJigw"
  }
}


resource "aws_route_table" "route-1a" {
  vpc_id = aws_vpc.AjVpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.AJigw.id
  }
  
  depends_on = [
    aws_vpc.AjVpc,
  ]

  tags = {
    Name = "route-1a"
  }
}


resource "aws_route_table_association" "associate-1a" {
  subnet_id      = aws_subnet.AJsubnet-1a.id
  route_table_id = aws_route_table.route-1a.id

  depends_on = [
    aws_subnet.AJsubnet-1a,
  ]
}


resource "aws_eip" "Ajnat" {
  vpc = true 
}


resource "aws_nat_gateway" "Ajnatgw" {
  allocation_id = aws_eip.Ajnat.id
  subnet_id     = aws_subnet.AJsubnet-1a.id

  tags = {
    Name = "Ajnatgw"
  }
}


resource "aws_route_table" "route-1b" {
  vpc_id = aws_vpc.AjVpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.Ajnatgw.id
  }
  
  depends_on = [
    aws_vpc.AjVpc,
  ]

  tags = {
    Name = "route-1b"
  }
}


resource "aws_route_table_association" "associate-1b" {
  subnet_id      = aws_subnet.AJsubnet-1b.id
  route_table_id = aws_route_table.route-1b.id

  depends_on = [
    aws_subnet.AJsubnet-1a,
  ]
}


resource "aws_security_group" "wordpress-sgroup" {
  name        = "wordpress-sgroup"
  description = "allow ssh and http"
  vpc_id      = aws_vpc.AjVpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_vpc.AjVpc,
  ]

  tags = {
    Name = "wordpress-sgroup"
  }
}



resource "aws_security_group" "bastion-sgroup" {
  name        = "bastion-sgroup"
  description = "ssh"
  vpc_id      = aws_vpc.AjVpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_vpc.AjVpc,
  ]

  tags = {
    Name = "bastion-sgroup"
  }
}




resource "aws_security_group" "Mysql-sgroup" {
  name        = "Mysql-sgroup"
  description = "wordpress and bastion SG"
  vpc_id      = aws_vpc.AjVpc.id

  ingress {
    description = "wordpress sgroup"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.wordpress-sgroup.id]
  }

  ingress {
    description = "for bastion sg"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion-sgroup.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  depends_on = [
    aws_vpc.AjVpc,
    aws_security_group.wordpress-sgroup,
    aws_security_group.bastion-sgroup
  ]

  tags = {
    Name = "Mysql-sgroup"
  }
}




resource "aws_instance" wordpress {
  ami = "ami-0604e98eec378ac0b"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.AJsubnet-1a.id
  key_name = "ekskey11"
  vpc_security_group_ids = [aws_security_group.wordpress-sgroup.id]

  depends_on = [
    aws_subnet.AJsubnet-1a,
    aws_security_group.wordpress-sgroup,
  ]

  tags = {
    Name = "wordpress"
  }
}




resource "aws_instance" Mysql {
  ami = "ami-02c572df3f58b33e8"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.AJsubnet-1b.id
  key_name = "ekskey11"
  vpc_security_group_ids = [aws_security_group.Mysql-sgroup.id]

  depends_on = [
    aws_subnet.AJsubnet-1b,
    aws_security_group.Mysql-sgroup,
  ]

  tags = {
    Name = "Mysql"
  }
}

resource "aws_instance" bastion {
  ami = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.AJsubnet-1a.id
  key_name = "ekskey11"
  vpc_security_group_ids = [aws_security_group.bastion-sgroup.id]

  depends_on = [
    aws_subnet.AJsubnet-1a,
    aws_security_group.bastion-sgroup,
  ]
  

  tags = {
    Name = "bastion"
  }
}

output "Ip_of_wordpress" {
  value = aws_instance.wordpress.public_ip
}


output "Ip_of_bastion" {
  value = aws_instance.bastion.public_ip
}

output "Ip_of_Mysql" {
  value = aws_instance.Mysql.private_ip
}