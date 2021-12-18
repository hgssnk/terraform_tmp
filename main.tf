variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {
    default = "ap-northeast-1"
}

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  profile = "hogemoge"
  region     = "${var.aws_region}"
}

# VPC作成
resource "aws_vpc" "aws-tf-vpc" {
  cidr_block           = "10.1.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  tags = {
    Name = "tf-example-vpc"
  }
}

# サブネット２つ作成(publicとprivate)
resource "aws_subnet" "aws-tf-public-subnet-1a" {
  vpc_id            = aws_vpc.aws-tf-vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "aws-tf-public-subnet-1a"
  }
}

resource "aws_subnet" "aws-tf-private-subnet-1a" {
  vpc_id            = aws_vpc.aws-tf-vpc.id
  cidr_block        = "10.1.20.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "aws-tf-private-subnet-1a"
  }
}

# インターネットゲートウェイの作成
resource "aws_internet_gateway" "aws-tf-igw" {
  vpc_id = aws_vpc.aws-tf-vpc.id
  tags = {
    Name = "aws-tf-igw"
  }
}

# ルートテーブルの作成
resource "aws_route_table" "aws-tf-public-route" {
  vpc_id = aws_vpc.aws-tf-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws-tf-igw.id
  }
  tags = {
    Name = "aws-tf-public-route"
  }
}

# サブネットの関連付けでルートテーブルをパブリックサブネットに紐付け
resource "aws_route_table_association" "aws-tf-public-subnet-association" {
  subnet_id      = aws_subnet.aws-tf-public-subnet-1a.id
  route_table_id = aws_route_table.aws-tf-public-route.id
}

# EC2作成(public側)
resource "aws_instance" "aws-tf-web" {
  ami                     = "ami-011facbea5ec0363b"
  instance_type           = "t2.micro"
  disable_api_termination = false
  key_name = aws_key_pair.auth.key_name
  vpc_security_group_ids  = [aws_security_group.aws-tf-web.id]
  subnet_id               = aws_subnet.aws-tf-public-subnet-1a.id

  tags = {
    Name = "aws-tf-web"
  }
}

# Security Group
resource "aws_security_group" "aws-tf-web" {
  name        = "aws-tf-web"
  description = "aws-tf-web_sg"
  vpc_id      = aws_vpc.aws-tf-vpc.id
  tags = {
    Name = "aws-tf-web"
  }
}

# 80番ポート許可のインバウンドルール
resource "aws_security_group_rule" "inbound_http" {
  type      = "ingress"
  from_port = 80
  to_port   = 80
  protocol  = "tcp"
  cidr_blocks = [
    "0.0.0.0/0",
  ]

  # ここでweb_serverセキュリティグループに紐付け
  security_group_id = aws_security_group.aws-tf-web.id
}

# 22番ポート許可のインバウンドルール
resource "aws_security_group_rule" "inbound_ssh" {
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = [
    "0.0.0.0/0",
  ]

  # ここでweb_serverセキュリティグループに紐付け
  security_group_id = aws_security_group.aws-tf-web.id
}

# アウトバウンドルール
resource "aws_security_group_rule" "outbound_all" {
  type      = "egress"
  from_port = 0
  to_port   = 0
  protocol  = -1
  cidr_blocks = [
    "0.0.0.0/0",
  ]

  # ここでweb_serverセキュリティグループに紐付け
  security_group_id = aws_security_group.aws-tf-web.id
}

# ElasticIP
resource "aws_eip" "aws-tf-eip" {
  instance = aws_instance.aws-tf-web.id
  vpc      = true
}
# output "example-public-ip" {
#     value = "${aws_eip.aws-tf-eip.public_ip}"
# }
variable "public_key_path" {}

resource "aws_key_pair" "auth" {
    key_name = "terraform-aws"
    public_key = file(var.public_key_path)
}

