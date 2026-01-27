locals {
  name_prefix = "${var.project}-${var.env}"
}
// Dev-friendly mode: optionally use the AWS default VPC and public subnets (no ALB, no NAT)

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 1) VPC (using terraform-aws-modules) - create only when use_default_vpc = false
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  count = var.use_default_vpc ? 0 : 1

  name = local.name_prefix
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = false
  single_nat_gateway = false
}

locals {
  name_prefix   = "${var.project}-${var.env}"
  vpc_id        = var.use_default_vpc ? data.aws_vpc.default.id : module.vpc[0].vpc_id
  public_subnets = var.use_default_vpc ? data.aws_subnets.default.ids : module.vpc[0].public_subnets
  private_subnets = var.use_default_vpc ? data.aws_subnets.default.ids : module.vpc[0].private_subnets
}

# Security group for ECS tasks: allow container port from internet (dev mode)
resource "aws_security_group" "ecs_sg" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Allow inbound to container port"
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

# ECR
resource "aws_ecr_repository" "repo" {
  name                 = "${local.name_prefix}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.repo.repository_url
}

# IAM roles for ECS task
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.name_prefix}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = "${local.name_prefix}-cluster"
}

# Task Definition
resource "aws_ecs_task_definition" "task" {
  family                   = "${local.name_prefix}-task"
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = jsonencode([
    {
      name      = "${local.name_prefix}"
      image     = var.container_image != "" ? var.container_image : aws_ecr_repository.repo.repository_url
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.name_prefix}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ECS Service (Fargate) - running in public subnets with public IP (dev mode)
resource "aws_ecs_service" "service" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = local.public_subnets
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}
