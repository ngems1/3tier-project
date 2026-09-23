region             = "us-east-1"
vpc_cidr_block     = "192.168.0.0/16"
alb_subnet_public  = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"]
web_subnet_private = ["192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24"]
app_subnet_private = ["192.168.7.0/24", "192.168.8.0/24", "192.168.9.0/24"]
db_subnet_private  = ["192.168.10.0/24", "192.168.11.0/24", "192.168.12.0/24"]

web_instance_type = "t3.small"
app_instance_type = "t3.small"

db_instance_class       = "db.t3.small"
db_engine               = "mysql"
db_engine_version       = "8.0"
db_parameter_group_name = "default.mysql8.0"
storage_encrypted       = false
db_allocated_storage    = 20
db_storage_type         = "gp3"
db_username             = "admin"
db_password             = "password" # NOTE: Consider using a safer way to pass secrets
db_name                 = "webappdb"

multi_az            = true
publicly_accessible = false

backup_retention_period = 7
backup_window           = "03:00-05:00"
maintenance_window      = "sun:07:00-sun:09:00"

skip_final_snapshot          = true
deletion_protection          = false
apply_immediately            = true
performance_insights_enabled = false

secret_username = "admin"
secret_password = "password"
secret_db_name  = "webappdb"

desired_capacity_web = 2
min_size_web         = 2
max_size_web         = 4

desired_capacity_app = 2
min_size_app         = 2
max_size_app         = 4

sns_topic_arn = "arn:aws:sns:us-east-1:970378220457:alb-demo-us-east-1"


hosted_zone_name = "harishshetty.xyz"
record_name      = "staging"



bastion_image_id      = "ami-08d7aabbb50c2c24e"
bastion_instance_type = "t2.micro"
bastion_tags          = { Name = "bastion-staging" }
bastion_key_name      = "us-new-keypair"

tags = {
  Project     = "vpc-alb"
  Environment = "staging"
}
