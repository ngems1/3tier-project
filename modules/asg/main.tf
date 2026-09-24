# web application load balancer
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [var.frontend_alb_sg_id]
  subnets         = var.public_subnets

  enable_deletion_protection = false
  idle_timeout               = 60

  tags = {
    Name        = "web_alb_${terraform.workspace}"
    Environment = "${terraform.workspace}"
    Project     = "vpc-alb"
    Tier        = "frontend"
  }
}

resource "aws_wafv2_web_acl" "web" {
  name  = "web-alb-${terraform.workspace}"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "web-alb-common-rules-${terraform.workspace}"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "web-alb-${terraform.workspace}"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "web" {
  resource_arn = aws_lb.web_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.web.arn
}

resource "aws_lb_target_group" "web" {
  name     = "web"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/healthz"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2

  }

  tags = {
    Name        = "web_tg_${terraform.workspace}"
    Environment = "${terraform.workspace}"
    Project     = "vpc-alb"
    Tier        = "frontend"
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web_alb.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "web_https" {
  load_balancer_arn = aws_lb.web_alb.id
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.id
  }
}

# web launch template
resource "aws_launch_template" "web" {
  name_prefix = "${terraform.workspace}_web"

  image_id      = var.web_image_id
  instance_type = var.web_instance_type

  vpc_security_group_ids = [var.web_sg_id]
  key_name               = var.key_name

  user_data = base64encode(templatefile("${path.root}/web_user_data.sh", {
    repository_url = var.web_ecr_repository_url
    region         = var.region
    environment    = var.environment
    app_alb_dns    = aws_lb.app_alb.dns_name
  }))

  monitoring {
    enabled = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.web_profile.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "web_${terraform.workspace}"
      Environment = "${terraform.workspace}"
      Project     = "vpc-alb"
      Tier        = "frontend"
    }
  }

}

resource "aws_autoscaling_group" "web" {
  name_prefix = "${terraform.workspace}_web"

  vpc_zone_identifier = var.web_private_subnets
  default_cooldown    = 60

  desired_capacity = var.desired_capacity_web
  min_size         = var.min_size_web
  max_size         = var.max_size_web

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  target_group_arns = [aws_lb_target_group.web.id]

  tag {
    key                 = "Name"
    value               = "web_${terraform.workspace}"
    propagate_at_launch = true
  }

}

# App ALB (Internal)
resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = true
  load_balancer_type = "application"

  security_groups = [var.backend_alb_sg_id]
  subnets         = var.public_subnets

  enable_deletion_protection = false
  idle_timeout               = 60

  tags = {
    Name        = "app_alb_${terraform.workspace}"
    Environment = "${terraform.workspace}"
    Project     = "vpc-alb"
    Tier        = "backend"
  }
}

resource "aws_lb_target_group" "app" {
  #checkov:skip=CKV_AWS_378:This internal-only ALB terminates traffic inside the VPC and forwards HTTP to private backend instances on the trusted application network.
  name     = "app"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/healthz"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2

  }

  tags = {
    Name        = "app_tg_${terraform.workspace}"
    Environment = "${terraform.workspace}"
    Project     = "vpc-alb"
    Tier        = "backend"
  }
}

resource "aws_lb_listener" "app" {
  #checkov:skip=CKV_AWS_103:This listener is internal-only on a private ALB; TLS is terminated at the public edge and intra-VPC traffic remains on the trusted network path.
  load_balancer_arn = aws_lb.app_alb.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.id
  }
}

resource "aws_launch_template" "app" {
  name_prefix = "${terraform.workspace}_app"

  image_id      = var.app_image_id
  instance_type = var.app_instance_type

  vpc_security_group_ids = [var.app_sg_id]
  key_name               = var.key_name

  user_data = base64encode(templatefile("${path.root}/app_user_data.sh", {
    repository_url = var.app_ecr_repository_url
    region         = var.region
    secret_name    = var.secret_name
    environment    = var.environment
    project_name   = var.project_name
  }))

  monitoring {
    enabled = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.app_profile.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "app_${terraform.workspace}"
      Environment = "${terraform.workspace}"
      Project     = "vpc-alb"
      Tier        = "backend"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name_prefix = "${terraform.workspace}_app"

  vpc_zone_identifier = var.app_private_subnets
  default_cooldown    = 60

  desired_capacity = var.desired_capacity_app
  min_size         = var.min_size_app
  max_size         = var.max_size_app

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  target_group_arns = [aws_lb_target_group.app.id]

  tag {
    key                 = "Name"
    value               = "app_${terraform.workspace}"
    propagate_at_launch = true
  }
}
