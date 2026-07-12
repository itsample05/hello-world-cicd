variable "aws_region" { type = string, default = "us-east-1" }
variable "app_name" { type = string, default = "hello-world" }
variable "container_image" { type = string }
variable "github_repository" { type = string, description = "owner/repository allowed to deploy" }
variable "vpc_cidr" { type = string, default = "10.0.0.0/16" }
variable "desired_count" { type = number, default = 1 }
