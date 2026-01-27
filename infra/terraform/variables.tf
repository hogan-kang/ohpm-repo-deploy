variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "ohpm-repo"
}

variable "env" {
  description = "Environment (dev/stage/prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "container_image" {
  description = "ECR image URI (e.g. <account>.dkr.ecr.<region>.amazonaws.com/ohpm-repo:tag)"
  type        = string
  default     = ""
}

variable "use_default_vpc" {
  description = "If true, use the AWS default VPC and its subnets (dev mode). If false, create a new VPC with module.vpc."
  type        = bool
  default     = true
}
