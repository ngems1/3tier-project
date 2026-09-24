# CloudWatch alarms for the RDS instance covering CPU, storage and connection
# pressure, notifying the shared SNS topic used across the project.

resource "aws_cloudwatch_metric_alarm" "db_cpu_high" {
  alarm_name          = "db_cpu_high_${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_utilization_threshold

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db_instance.id
  }

  alarm_description  = "RDS CPU utilization above ${var.cpu_utilization_threshold}%"
  alarm_actions      = [var.sns_topic_arn]
  ok_actions         = [var.sns_topic_arn]
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "db_free_storage_low" {
  alarm_name          = "db_free_storage_low_${terraform.workspace}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.free_storage_space_threshold_bytes

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db_instance.id
  }

  alarm_description  = "RDS free storage space below threshold"
  alarm_actions      = [var.sns_topic_arn]
  ok_actions         = [var.sns_topic_arn]
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "db_connections_high" {
  alarm_name          = "db_connections_high_${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.max_connections_threshold

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db_instance.id
  }

  alarm_description  = "RDS database connections above ${var.max_connections_threshold}"
  alarm_actions      = [var.sns_topic_arn]
  ok_actions         = [var.sns_topic_arn]
  treat_missing_data = "notBreaching"
}
