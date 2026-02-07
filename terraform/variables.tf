// AWS Region Configuration
variable "aws_region" {
  description = "AWS deployment region (set to ap-east-1 for Hong Kong)"
  type        = string
  default     = "ap-east-1"
}

// Project Identifier
variable "project" {
  description = "Project name identifier"
  type        = string
  default     = "ohpm-repo"
}

// Environment Configuration
variable "env" {
  description = "Deployment environment identifier"
  type        = string
  default     = "dev"
}

// Container Port
variable "container_port" {
  description = "Container expose port - HTTP standard port 80"
  type        = number
  default     = 80
}

// Docker Image Configuration
variable "container_image" {
  description = "Docker Hub public image address (no ECR needed)"
  type        = string
  default     = "nginx:alpine"
}

