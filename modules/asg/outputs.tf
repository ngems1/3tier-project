output "web_alb_dns_name" {
  description = "DNS name of the Web Application Load Balancer"
  value       = aws_lb.web_alb.dns_name
}

output "app_alb_dns_name" {
  description = "DNS name of the App Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "web_alb_zone_id" {
  description = "Zone ID of the Web Application Load Balancer"
  value       = aws_lb.web_alb.zone_id
}

output "web_alb_arn_suffix" {
  description = "ARN suffix of the Web ALB, for CloudWatch metric dimensions"
  value       = aws_lb.web_alb.arn_suffix
}

output "app_alb_arn_suffix" {
  description = "ARN suffix of the App (internal) ALB, for CloudWatch metric dimensions"
  value       = aws_lb.app_alb.arn_suffix
}

output "web_tg_arn_suffix" {
  description = "ARN suffix of the Web target group, for CloudWatch metric dimensions"
  value       = aws_lb_target_group.web.arn_suffix
}

output "app_tg_arn_suffix" {
  description = "ARN suffix of the App target group, for CloudWatch metric dimensions"
  value       = aws_lb_target_group.app.arn_suffix
}

output "web_asg_name" {
  description = "Name of the Web Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "app_asg_name" {
  description = "Name of the App Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

