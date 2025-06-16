resource "aws_lb" "oracle_alb" {
  name               = "oracle-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.oracle_sg.id]
  subnets            = module.oracle_vpc.public_subnets
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.oracle_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.oracle_cert_validated.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.oracle_tg.arn
  }
}

resource "aws_security_group" "oracle_sg" {
  name        = "oracle-sg"
  description = "Allow HTTPS and HTTP"
  vpc_id      = module.oracle_vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "oracle_tg" {
  name        = "oracle-tg"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.oracle_vpc.vpc_id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}
