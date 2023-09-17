terraform {
  backend "s3" {
    bucket         = "dev-applications-backend-state-worachai"
    key            = "dev/05-ec2-instance/web/backend-state"
    region         = "us-east-1"
    dynamodb_table = "dev-applications-locks"
    encrypt        = true
  }
}

variable "AWS_ACCESS_KEY_ID" {
    type = string
}
variable "AWS_SECRET_ACCESS_KEY" {
    type = string
}
variable "AWS_DEFAULT_REGION" {
    type = string
}
variable "ECR_REPOSITORY" {
    type = string
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

  subnet_id = data.aws_subnets.default_subnets.ids[0]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum -y update
              sudo yum -y install docker
              sudo service docker start
              sudo usermod -a -G docker ec2-user
              export AWS_ACCESS_KEY_ID=${var.AWS_ACCESS_KEY_ID}
              export AWS_SECRET_ACCESS_KEY=${var.AWS_SECRET_ACCESS_KEY}
              aws ecr get-login-password --region ${var.AWS_REGION} | docker login --username AWS --password-stdin ${var.ECR_REPOSITORY}
              sudo docker run -d -p 5000:5000 ${var.ECR_REPOSITORY}/simple-web-app:latest
              EOF

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  depends_on = [ aws_iam_instance_profile.ec2_instance_profile ]
}

resource "aws_iam_policy" "ec2_policy" {
  name        = "ec2_policy"
  description = "Allow EC2 to access ECR"
  policy      = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:*",
                "cloudtrail:LookupEvents"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": [
                        "replication.ecr.amazonaws.com"
                    ]
                }
            }
        }
    ]})
}

resource "aws_iam_role" "ec2_role" {
  name               = "ec2_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]})
}

resource "aws_iam_role_policy_attachment" "ec2_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
  
  depends_on = [ aws_iam_policy.ec2_policy, aws_iam_role.ec2_role ]
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name

  depends_on = [ aws_iam_role.ec2_role ]
}