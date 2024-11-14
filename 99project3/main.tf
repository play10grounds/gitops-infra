# VPC 생성

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# VPC 생성
resource "aws_vpc" "vpc" {
  cidr_block = "172.16.0.0/20"
  enable_dns_hostnames =  true
  enable_dns_support = true

  tags = { Name = "project_vpc" }
}

# 서브넷 생성
resource "aws_subnet" "pub_subnet" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "172.16.0.0/24"
  availability_zone = "ap-northeast-2a"

  tags = { Name = "project_pub_subnet" }
}

# 인터넷 게이트웨이
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = { Name = "project_igw" }
}

# 라우팅 테이블 생성 및 인터넷 게이트웨이 연결
resource "aws_route_table" "pub_rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# 서브넷과 라우팅 테이블 연결
resource "aws_route_table_association" "rtbasso" {
  route_table_id = aws_route_table.pub_rtb.id
  subnet_id = aws_subnet.pub_subnet.id
}

# 보안그룹 생성
resource "aws_security_group" "pub_sg" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "project_pub_sg" }
}

# ----

# 프라이빗 서브넷 생성
resource "aws_subnet" "prv_subnet" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "172.16.2.0/24"
  availability_zone = "ap-northeast-2a"

  tags = { Name = "project_prv_subnet" }
}

# NAT 게이트웨이 생성 및 연결
resource "aws_eip" "eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = { Name = "project_eip" }
}

resource "aws_nat_gateway" "natgw" {
  subnet_id = aws_subnet.pub_subnet.id
  allocation_id = aws_eip.eip.allocation_id

  tags = { Name = "project_natgw" }
}

# 라우팅 테이블 생성 및 NAT 게이트웨이 연결
resource "aws_route_table" "prv_rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
}

# 서브넷과 라우팅 테이블 연결
resource "aws_route_table_association" "rtb2asso" {
  route_table_id = aws_route_table.prv_rtb.id
  subnet_id = aws_subnet.prv_subnet.id
}

# 보안그룹 생성
resource "aws_security_group" "prv_sg" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "project_prv_sg" }
}

# ------------------

# EC2 인스턴스 생성
resource "aws_instance" "gitops1" {
  ami           = "ami-0a9ca67a102bd2bc8"
  instance_type = "t4g.small"
  key_name      = "clouds2024"

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
    delete_on_termination = true  # 인스턴스 종료시 볼륨도 삭제
  }

  vpc_security_group_ids = [aws_security_group.pub_sg.id]
  subnet_id = aws_subnet.pub_subnet.id # 사용자 정의 서브넷
  associate_public_ip_address = true  # 퍼블릭 IP 할당

  tags = { Name = "gitops1" }

  user_data = filebase64("${path.module}/ansible_nginx_user_data.sh")

}

resource "aws_instance" "gitops2" {
  ami           = "ami-0a9ca67a102bd2bc8"
  instance_type = "t4g.medium"
  key_name      = "clouds2024"

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
    delete_on_termination = true  # 인스턴스 종료시 볼륨도 삭제
  }

  vpc_security_group_ids = [aws_security_group.prv_sg.id]
  subnet_id = aws_subnet.prv_subnet.id
  associate_public_ip_address = false  # 프라이빗 IP만 할당

  tags = { Name = "gitops2" }

  user_data = filebase64("${path.module}/gitops_user_data.sh")

}

resource "aws_instance" "gitops3" {
  ami           = "ami-0a9ca67a102bd2bc8"
  instance_type = "t4g.small"
  key_name      = "clouds2024"

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
    delete_on_termination = true  # 인스턴스 종료시 볼륨도 삭제
  }

  vpc_security_group_ids = [aws_security_group.prv_sg.id]
  subnet_id = aws_subnet.prv_subnet.id
  associate_public_ip_address = false  # 프라이빗 IP만 할당

  tags = { Name = "gitops3" }

  user_data = filebase64("${path.module}/gitops_user_data.sh")

}

output "gitops1_public_ip" {
  value = aws_instance.gitops1.public_ip
}

output "gitops2_private_ip" {
  value = aws_instance.gitops2.private_ip
}

output "gitops3_private_ip" {
  value = aws_instance.gitops3.private_ip
}