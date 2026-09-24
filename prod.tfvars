region             = "ap-south-1"
vpc_cidr_block     = "10.80.0.0/16"
alb_subnet_public  = ["10.80.1.0/24", "10.80.2.0/24", "10.80.3.0/24"]
web_subnet_private = ["10.80.4.0/24", "10.80.5.0/24", "10.80.6.0/24"]
app_subnet_private = ["10.80.7.0/24", "10.80.8.0/24", "10.80.9.0/24"]
db_subnet_private  = ["10.80.10.0/24", "10.80.11.0/24", "10.80.12.0/24"]

web_instance_type = "t3.medium"
app_instance_type = "t3.medium"

db_instance_class       = "db.t3.medium"
db_engine               = "mysql"
db_engine_version       = "8.0"
db_parameter_group_name = "default.mysql8.0"
storage_encrypted       = true
db_allocated_storage    = 50
db_storage_type         = "gp3"
db_username             = "admin"
db_password             = "password" # NOTE: Replace with a value injected via CI secrets / Secrets Manager, never commit real prod credentials
db_name                 = "webappdb"

multi_az            = true
publicly_accessible = false

backup_retention_period = 30
backup_window           = "03:00-05:00"
maintenance_window      = "sun:07:00-sun:09:00"

skip_final_snapshot          = false
deletion_protection          = true
apply_immediately            = false
performance_insights_enabled = true

secret_username = "admin"
secret_password = "password"
secret_db_name  = "webappdb"

desired_capacity_web = 2
min_size_web         = 2
max_size_web         = 6

desired_capacity_app = 2
min_size_app         = 2
max_size_app         = 6

sns_topic_arn = "arn:aws:sns:ap-south-1:970378220457:alb-sns-demo"

hosted_zone_name   = "ngems.xyz"
record_name        = "prod"
certificate_domain = "ngems.xyz"

bastion_image_id      = "ami-0c44f651ab5e9285f"
bastion_instance_type = "t2.micro"
bastion_tags          = { Name = "bastion-prod" }
bastion_key_name      = "new-keypair"

log_retention_days = 90

tags = {
  Project     = "vpc-alb"
  Environment = "prod"
}
