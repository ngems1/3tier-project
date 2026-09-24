# CloudWatch Log Groups for the web/app tiers (application + web server logs
# shipped by the CloudWatch Agent) with a bounded retention period, and
# CloudWatch alarms covering ALB health, latency and error rate for both
# tiers, notifying the shared SNS topic.

resource "aws_cloudwatch_log_group" "web" {
  name              = "/three-tier/${terraform.workspace}/web"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = "${terraform.workspace}"
    Project     = "vpc-alb"
    Tier        = "frontend"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/three-tier/${terraform.workspace}/app"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = "${terraform.workspace}"
    Project     = "vpc-alb"
    Tier        = "backend"
  }
}

# --- Web ALB / target group alarms -----------------------------------------

resource "aws_cloudwatch_metric_alarm" "web_unhealthy_hosts" {
  alarm_name          = "web_unhealthy_hosts_${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0

  dimensions = {
    LoadBalancer = aws_lb.web_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.web.arn_suffix
  }

  alarm_description  = "Web target group has unhealthy hosts"
  alarm_actions      = [var.sns_topic_arn]
  ok_actions         = [var.sns_topic_arn]
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "web_5xx_errors" {
  alarm_name          = "web_5xx_errors_${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold

  dimensions = {
    LoadBalancer = aws_lb.web_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.web.arn_suffix
  }

  alarm_description  = "Web tier returning elevated 5XX errors"
  alarm_actions      = [var.sns_topic_arn]
  ok_actions         = [var.sns_topic_arn]
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "web_response_time_high" {
  alarm_name          = "web_response_time_high_${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = var.alb_response_time_threshold

  dimensions = {
    LoadBalancer = aws_lb.web_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.web.arn_suffix
  }

  alarm_description  = "Web tier target response time above ${var.alb_response_time_threshold}s"
  alarm_actions      = [var.sns_topic_arn]
  ok_actions         = [var.sns_topic_arn]
  treat_missing_data = "notBreaching"
}

# --- App (internal) ALB / target group alarms -------------------------------

resource "aws_cloudwatch_metric_alarm" "app_unhealthy_hosts" {
  alarm_name          = "app_unhealthy_hosts_${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0

  dimensions = {
    LoadBalancer = aws_lb.app_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_description  = "App target group has unhealthy hosts"
  alarm_actions      = [var.sns_topic_arn]
  ok_actions         = [var.sns_topic_arn]
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "app_5xx_errors" {
  alarm_name          = "app_5xx_errors_${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold

  dimensions = {
    LoadBalancer = aws_lb.app_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_description  = "App tier returning elevated 5XX errors"
  alarm_actions      = [var.sns_topic_arn]
  ok_actions         = [var.sns_topic_arn]
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "app_response_time_high" {
  alarm_name          = "app_response_time_high_${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = var.alb_response_time_threshold

  dimensions = {
    LoadBalancer = aws_lb.app_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_description  = "App tier target response time above ${var.alb_response_time_threshold}s"
  alarm_actions      = [var.sns_topic_arn]
  ok_actions         = [var.sns_topic_arn]
  treat_missing_data = "notBreaching"
}
