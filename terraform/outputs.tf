# ECS Outputs
output "cluster_name" {
  value       = aws_ecs_cluster.cluster.name
  description = "ECS cluster name"
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.task.arn
  description = "ECS task definition ARN"
}

# EFS Outputs
output "efs_file_system_id" {
  value       = aws_efs_file_system.app_efs.id
  description = "EFS file system ID"
}

# Container Outputs
output "container_image_used" {
  value       = var.container_image
  description = "Docker image"
}

# Quick Reference
output "quick_reference" {
  value = {
    region  = var.aws_region
    project = var.project
    env     = var.env
  }
  description = "Quick reference information"
}
