# AWS Region Configuration
variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "ap-east-1"
}

# Desired count for ECS service
variable "desired_count" {
  description = "Number of desired tasks for the ECS service"
  type        = number
  default     = 2
}

# Public Subnet Configuration (for NAT Gateway)
variable "public_subnet_az1" {
  description = "Public Subnet ID for AZ1 (for NAT Gateway)"
  type        = string
}

variable "public_subnet_az2" {
  description = "Public Subnet ID for AZ2 (for NAT Gateway)"
  type        = string
}

# Private Subnet CIDR Configuration (Terraform will create private subnets)
variable "private_subnet_cidr_az1" {
  description = "Private Subnet CIDR for AZ1"
  type        = string
  default     = "172.31.128.0/20"
}

variable "private_subnet_cidr_az2" {
  description = "Private Subnet CIDR for AZ2"
  type        = string
  default     = "172.31.144.0/20"
}

# Project Identifier
variable "project" {
  description = "Project name identifier"
  type        = string
  default     = "ohpm-repo"
}

# Environment Configuration
variable "env" {
  description = "Deployment environment identifier"
  type        = string
  default     = "dev"
}

# Container Port
variable "container_port" {
  description = "Container expose port - HTTP standard port 80"
  type        = number
  default     = 80
}

# Docker Image Configuration
variable "container_image" {
  description = "Docker Hub public image address"
  type        = string
  default     = "nginx:alpine"
}
