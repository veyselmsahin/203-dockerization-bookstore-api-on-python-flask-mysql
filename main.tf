terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}
provider "github" {
  token = "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"
}
resource "github_repository" "myrepo" {
  name        = "bookstore-api-repo"
  description = "Project 203! "
  auto_init   = true
}
resource "github_branch_default" "main"{
  repository = github_repository.myrepo.name
  branch     = "main"
}
variable "files" {
  default = ["bookstore-api.py", "docker-compose.yaml", "Dockerfile", "requirements.txt"]
}
resource "github_repository_file" "foo" {
  for_each = toset(var.files)
  repository          = github_repository.myrepo.name
  branch              = "main"
  file                = each.value
  content             = file(each.value)
  commit_message      = "Managed by Terraform"
  overwrite_on_create = true
}
resource "aws_instance" "tf-docker-ec2" {
  ami = "ami-0dbc3d7bc646e8516"
  instance_type = "t2.micro"
  tags = {
    Name = "bookstore-203-project"
  }
  vpc_security_group_ids = [aws_security_group.tf-docker-sec-gr]
  key_name = "nbewkey"
  user_data = <<-EOF
          #! /bin/bash
          yum update -y
          yum install docker -y
          systemctl start docker
          systemctl enable docker
          usermod -a -G docker ec2-user
          newgrp docker
          curl -SL https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
          chmod +x /usr/local/bin/docker-compose
          mkdir -p /home/ec2-user/bookstore-api
          TOKEN="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"
          FOLDER="https://$TOKEN@raw.githubusercontent.com/veysel/bookstore-api-repo/main/"
          curl -s --create-dirs -o "/home/ec2-user/bookstore-api/app.py" -L "$FOLDER"bookstore-api.py
          curl -s --create-dirs -o "/home/ec2-user/bookstore-api/requirements.txt" -L "$FOLDER"requirements.txt
          curl -s --create-dirs -o "/home/ec2-user/bookstore-api/Dockerfile" -L "$FOLDER"Dockerfile
          curl -s --create-dirs -o "/home/ec2-user/bookstore-api/docker-compose.yaml" -L "$FOLDER"docker-compose.yaml
          cd /home/ec2-user/bookstore-api
          docker build -t veyseldocker/bookstoreapi:latest .
          docker-compose up -d
          EOF
}
resource "aws_security_group" "tf-docker-sec-gr" {
  name = "docker-sec-gr-203-veysel"
  tags = {
    Name = "docker-sec-group-203"
  }
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
output "website" {
  value = "http://${aws_instance.tf-docker-ec2.public_dns}"
}