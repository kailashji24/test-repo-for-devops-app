terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
}

variable "region" { default = "ap-south-1" }
variable "instance_type" { default = "t3.micro" }
variable "app_bucket_name" { default = "assignment2-app-bucket" } 
variable "jar_key" { default = "builds/app.jar" }
variable "logs_bucket_name" { default = "" }
variable "asg_min" { default = 1 }
variable "asg_max" { default = 10 }
variable "asg_desired" { default = 1 }
variable "email" { default = "haaji0458@gmail.com" }