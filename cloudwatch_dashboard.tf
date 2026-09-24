# Consolidated CloudWatch dashboard covering both ALBs, both Auto Scaling
# Groups (CPU) and the RDS instance (CPU, storage, connections), giving a
# single place to observe the health of the whole 3-tier stack.

resource "aws_cloudwatch_dashboard" "three_tier" {
  dashboard_name = "three-tier-${terraform.workspace}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Web ALB - Requests & Errors"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.asg.web_alb_arn_suffix, { stat = "Sum" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", module.asg.web_alb_arn_suffix, "TargetGroup", module.asg.web_tg_arn_suffix, { stat = "Sum" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.asg.web_alb_arn_suffix, "TargetGroup", module.asg.web_tg_arn_suffix, { stat = "Average" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "App ALB - Requests & Errors"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.asg.app_alb_arn_suffix, { stat = "Sum" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", module.asg.app_alb_arn_suffix, "TargetGroup", module.asg.app_tg_arn_suffix, { stat = "Sum" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.asg.app_alb_arn_suffix, "TargetGroup", module.asg.app_tg_arn_suffix, { stat = "Average" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Auto Scaling Group CPU Utilization"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.asg.web_asg_name, { label = "Web ASG" }],
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.asg.app_asg_name, { label = "App ASG" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "RDS - CPU, Storage & Connections"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", module.rds.db_instance_id, { label = "CPU %" }],
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", module.rds.db_instance_id, { label = "Free storage (bytes)", yAxis = "right" }],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", module.rds.db_instance_id, { label = "Connections" }],
          ]
        }
      },
    ]
  })
}
