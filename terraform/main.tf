terraform {
  backend "s3" {
    bucket         = "dev-applications-backend-state-worachai"
    key            = "dev/05-ec2-instance/web/backend-state"
    region         = "us-east-1"
    dynamodb_table = "dev-applications-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_security_group" "web_app_sg" {
  name   = "web_app_sg"
  vpc_id = aws_default_vpc.default.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_app_sg"
  }
}

resource "aws_instance" "web_app" {
  ami                    = data.aws_ami.aws-linux-2-latest.id
  key_name               = "default-ec2"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_app_sg.id]

  for_each  = toset(data.aws_subnets.default_subnets.ids)
  subnet_id = each.value

  user_data = <<-EOF
              #!/bin/bash
              sudo yum -y update
              sudo yum -y install docker
              sudo service docker start
              sudo usermod -a -G docker ec2-user
              sudo docker run -d -p 5000:5000 568406210619.dkr.ecr.us-east-1.amazonaws.com/simple-web-app:latest
              EOF
}