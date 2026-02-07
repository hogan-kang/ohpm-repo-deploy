// Fetch default VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

// Local variables
locals {
  name_prefix   = "${var.project}-${var.env}"
  vpc_id        = data.aws_vpc.default.id
  public_subnets = data.aws_subnets.default.ids
}

# ECS Security Group
resource "aws_security_group" "ecs_sg" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "ECS and EFS security group"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS IAM Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.name_prefix}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

// ECS task trust policy
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Attach execution policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = "${local.name_prefix}-cluster"
}

# EFS File System
resource "aws_efs_file_system" "app_efs" {
  creation_token = "${local.name_prefix}-efs"
  
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  performance_mode = "generalPurpose"
  throughput_mode = "elastic"

  tags = {
    Name = "${local.name_prefix}-efs"
  }
}

# EFS Mount Target 
resource "aws_efs_mount_target" "efs_mount" {
  count = 1

  file_system_id  = aws_efs_file_system.app_efs.id
  subnet_id       = local.public_subnets[0]
  security_groups = [aws_security_group.ecs_sg.id]
}

# NFS Security Group Rule
resource "aws_security_group_rule" "efs_ingress" {
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_sg.id
  description       = "NFS for EFS"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "task" {
  family                   = "${local.name_prefix}-task"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  
  container_definitions = jsonencode([
    {
      name      = "${local.name_prefix}"
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "efs-storage"
          containerPath = "/usr/share/nginx/html"
          readOnly      = false
        }
      ]
      stopTimeout = 30
      command = [
        "sh",
        "-c",
        "echo '<html><body><h1>Hello from EFS!</h1><p>Test page created at: $(date)</p></body></html>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"
      ]
    }
  ])
  
  volume {
    name = "efs-storage"
    
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.app_efs.id
      root_directory = "/"
    }
  }
}

# ECS Service
resource "aws_ecs_service" "service" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [local.public_subnets[0]]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}