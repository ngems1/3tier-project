region             = "ap-south-1"
vpc_cidr_block     = "10.75.0.0/16"
alb_subnet_public  = ["10.75.1.0/24", "10.75.2.0/24", "10.75.3.0/24"]
web_subnet_private = ["10.75.4.0/24", "10.75.5.0/24", "10.75.6.0/24"]
app_subnet_private = ["10.75.7.0/24", "10.75.8.0/24", "10.75.9.0/24"]
db_subnet_private  = ["10.75.10.0/24", "10.75.11.0/24", "10.75.12.0/24"]

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

desired_capacity_web = 1
min_size_web         = 1
max_size_web         = 2

desired_capacity_app = 2
min_size_app         = 2
max_size_app         = 4

sns_topic_arn = "arn:aws:sns:ap-south-1:970378220457:alb-sns-demo" # create your own sns topic


hosted_zone_name = "harishshetty.xyz" # create your own hosted zone
record_name      = "dev"



bastion_image_id      = "ami-0c44f651ab5e9285f" # change this to your own ami id
bastion_instance_type = "t2.micro"
bastion_tags          = { Name = "bastion-dev" }
bastion_key_name      = "new-keypair" # create your own key pair

tags = {
  Project     = "vpc-alb"
  Environment = "dev"
}
