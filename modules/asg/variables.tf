variable "vpc_id" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "web_private_subnets" {
  type = list(string)
}

variable "app_private_subnets" {
  type = list(string)
}

variable "frontend_alb_sg_id" {
  type = string
}

variable "backend_alb_sg_id" {
  type = string
}

variable "web_instance_type" {
  type = string
}

variable "app_instance_type" {
  type = string
}

variable "web_image_id" {
  type = string
}

variable "app_image_id" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "secret_name" {
  type = string
}

variable "web_ecr_repository_url" {
  type = string
}

variable "app_ecr_repository_url" {
  type = string
}

variable "sns_topic_arn" {
  type = string
}

variable "secret_arn" {
  type = string
}

variable "desired_capacity_web" {
  type = number
}

variable "min_size_web" {
  type = number
}

variable "max_size_web" {
  type = number
}

variable "desired_capacity_app" {
  type = number
}

variable "min_size_app" {
  type = number
}

variable "max_size_app" {
  type = number
}

variable "web_sg_id" {
  type = string
}

variable "app_sg_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "certificate_arn" {
  type = string
}

variable "log_retention_days" {
  description = "Retention (days) for the CloudWatch Log Groups used by the web/app tiers"
  type        = number
  default     = 14
}

variable "alb_5xx_threshold" {
  description = "Threshold for ALB target 5XX error count alarms"
  type        = number
  default     = 5
}

variable "alb_response_time_threshold" {
  description = "Threshold (seconds) for ALB target response time alarms"
  type        = number
  default     = 2
}
