resource "aws_ecs_cluster" "oracle_cluster" {
  name = "oracle-cluster"
}

resource "aws_cloudwatch_log_group" "oracle_logs" {
  name              = "/ecs/oracle-app"
  retention_in_days = 7
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole_Oracle"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "oracle_task" {
  family                   = "oracle-task"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "oracle-container",
      image     = var.container_image,
      portMappings = [
        {
          containerPort = 8000,
          hostPort      = 8000,
          protocol      = "tcp"
        }
      ],
      environment = [
        { name = "AWS_REGION", value = var.aws_region },
        { name = "S3_BUCKET", value = var.s3_bucket_name },
        { name = "OPENAI_API_KEY", value = var.openai_api_key }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.oracle_logs.name,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "oracle_service" {
  name            = "oracle-service"
  cluster         = aws_ecs_cluster.oracle_cluster.id
  task_definition = aws_ecs_task_definition.oracle_task.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = module.oracle_vpc.public_subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.oracle_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.oracle_tg.arn
    container_name   = "oracle-container"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.https]
}

resource "aws_iam_policy" "s3_audio_write" {
  name   = "oracle-s3-audio-write"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["s3:PutObject"],
      Resource = "arn:aws:s3:::${var.s3_bucket_name}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_audio_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.s3_audio_write.arn
}

resource "aws_iam_role_policy_attachment" "oracle_audio_access_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.oracle_audio_s3_access.arn
}
