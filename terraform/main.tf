# Fetch default VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Local variables
locals {
  name_prefix   = "${var.project}-${var.env}"
  vpc_id        = data.aws_vpc.default.id
}

# ECS Security Group
resource "aws_security_group" "ecs_sg" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "ECS and EFS security group"
  vpc_id      = local.vpc_id

  # Allow traffic from ALB
  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups  = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS IAM Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${local.name_prefix}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

# ECS task trust policy
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
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
  throughput_mode  = "elastic"

  tags = {
    Name = "${local.name_prefix}-efs"
  }
}

# NAT Gateway
resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = var.public_subnet_az1

  tags = {
    Name = "${local.name_prefix}-nat"
  }
}

# Private Subnets
resource "aws_subnet" "private_az1" {
  vpc_id            = local.vpc_id
  cidr_block        = var.private_subnet_cidr_az1
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${local.name_prefix}-private-az1"
  }
}

resource "aws_subnet" "private_az2" {
  vpc_id            = local.vpc_id
  cidr_block        = var.private_subnet_cidr_az2
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${local.name_prefix}-private-az2"
  }
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = local.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${local.name_prefix}-private-rt"
  }
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private_az1" {
  subnet_id      = aws_subnet.private_az1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_az2" {
  subnet_id      = aws_subnet.private_az2.id
  route_table_id = aws_route_table.private.id
}

# EFS Mount Target
resource "aws_efs_mount_target" "efs_mount" {
  count = 2

  file_system_id  = aws_efs_file_system.app_efs.id
  subnet_id       = count.index == 0 ? aws_subnet.private_az1.id : aws_subnet.private_az2.id
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

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB
resource "aws_lb" "app_alb" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets           = [var.public_subnet_az1, var.public_subnet_az2]

  enable_deletion_protection = false

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "app_tg" {
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "${local.name_prefix}-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  tags = {
    Name = "${local.name_prefix}-listener"
  }
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
    subnets          = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "${local.name_prefix}"
    container_port   = var.container_port
  }

  # ALB dependency
  depends_on = [
    aws_lb_listener.app_listener
  ]
}

# Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "alb_url" {
  description = "URL to access the application via ALB"
  value       = "http://${aws_lb.app_alb.dns_name}"
}

output "ecs_cluster_name" {
  description = "Name of the ECS Cluster"
  value       = aws_ecs_cluster.cluster.name
}

output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.app_efs.id
}

output "target_group_arn" {
  description = "ARN of the ALB Target Group"
  value       = aws_lb_target_group.app_tg.arn
}
