# Development Environment Configuration - Cost Optimized

# AWS Region: Hong Kong (ap-east-1)
aws_region = "ap-east-1"

# Project Identifier
project = "ohpm-repo"

# Environment Configuration
env = "dev"

# Desired count for ECS service in dev
desired_count = 2

# Container Port: HTTP standard port 80
container_port = 80

# Docker Image: nginx:alpine from Docker Hub
# Test NAT Gateway connectivity
container_image = "nginx:alpine"

# Multi-AZ Subnet Configuration
# Public subnets (for NAT Gateway) - Using AWS default public subnets
public_subnet_az1 = "subnet-03b0f61a5d80d03e1" # ap-east-1a
public_subnet_az2 = "subnet-0ac9b826ce0116170" # ap-east-1b

# Private subnet CIDR configuration (Terraform will create private subnets)
private_subnet_cidr_az1 = "172.31.128.0/20"
private_subnet_cidr_az2 = "172.31.144.0/20"
