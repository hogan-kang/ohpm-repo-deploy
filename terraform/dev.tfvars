# Development Environment Configuration - Cost Optimized

# AWS Region: Hong Kong (ap-east-1)
aws_region      = "ap-east-1"

# Project Identifier
project         = "ohpm-repo"

# Environment Configuration
env             = "dev"

# Desired count for ECS service in dev
desired_count   = 1

# Container Port: HTTP standard port 80
container_port  = 80

# Docker Image: nginx:alpine from Docker Hub
container_image = "nginx:alpine"
