#PROVIDER
provider "aws" {
  region                  = var.main_region
}

#DATA
#to get latest AMI
# data "aws_ssm_parameter" "windows" {
#   name = "/aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base"
# }

data "aws_ssm_parameter" "linux" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

#to get current accountID
data "aws_caller_identity" "current" {}

#RESOURCES

module "vpc" {
  source = "app.terraform.io/Test_Vault/vpc/aws"
  region = var.main_region
  version = "1.0.2"
}

#EC2
resource "aws_instance" "bas" {
  ami                    = "${data.aws_ssm_parameter.linux.value}"
  instance_type          = "t2.micro"
  # key_name               = "itrams-dm-platform-uat-dmz-bh-keypair"
  subnet_id              = module.vpc.public_subnet1
  vpc_security_group_ids = [module.vpc.bas_sg]
  # iam_instance_profile   = "AmazonEC2SSM"
  tags = {
    Name = "cummin-uat-bastion-host"
  }
}



# EIP for bastion host
resource "aws_eip" "bas" {
  instance = aws_instance.bas.id
}

# ALB for ECS
resource "aws_lb" "alb" {
  name               = "cummin-uat-alb"
  load_balancer_type = "application"
  security_groups    = [module.vpc.alb_sg]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "ecs" {
  name     = "cummin-dev-ecs-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

#Subnet group for rds
resource "aws_db_subnet_group" "rds" {
  name       = "itrams-dm-platform-uat-subnet-group"
  subnet_ids = module.vpc.rds_subnets
}

#RDS
# resource "aws_db_instance" "rds" {
#   allocated_storage      = 20
#   engine                 = "mysql"
#   instance_class         = "db.t2.small"
#   identifier             = "itrams-dm-platform-uat-db-01"
#   username               = "dmuatdbadmin"
#   password               = var.database_master_password
#   db_subnet_group_name   = aws_db_subnet_group.rds.name
#   vpc_security_group_ids = [module.vpc.rds_sg]
#   maintenance_window     = "fri:10:24-fri:10:54"
#   backup_window          = "22:33-23:03"
#   copy_tags_to_snapshot  = "true"
#   deletion_protection    = "true"
# }

#ECS
resource "aws_ecs_cluster" "cluster" {
  name = "cummin-uat-ecs-cluster"
}


#SNS topics
# resource "aws_sns_topic" "sms" {
#   name = "Critical-SMS-alert"
# }

# resource "aws_sns_topic" "rbvh" {
#   name = "RBVH_Monitoring"
# }

# #SNS topic subscriptions
# resource "aws_sns_topic_subscription" "email" {
#   topic_arn = aws_sns_topic.sms.arn
#   protocol  = "email"
#   endpoint  = "hoan.lac@outlook.com"
# }

# resource "aws_sns_topic_subscription" "sms" {
#   topic_arn = aws_sns_topic.sms.arn
#   protocol  = "sms"
#   endpoint  = "+84823372325"
# }

# resource "aws_sns_topic_subscription" "email_rbvh" {
#   topic_arn = aws_sns_topic.rbvh.arn
#   protocol  = "email"
#   endpoint  = "RBVH.CloudOps@vn.bosch.com"
# }

#Guardduty
# resource "aws_guardduty_detector" "guardduty" {
#   enable = true
# }

#CloudWatch log group
# resource "aws_cloudwatch_log_group" "cloudtrail" {
#   name = "aws-cloudtrail-logs"
# }

#S3
#bucket for cloudtrail
# resource "aws_s3_bucket" "log" {
#   bucket        = "itrams-dm-prod-cloudtrail-${var.main_region}"
#   force_destroy = "true"
#   policy        = <<POLICY
# {
#         "Version": "2012-10-17",
#         "Statement": [
#             {
#                 "Sid": "AWSCloudTrailAclCheck",
#                 "Effect": "Allow",
#                 "Principal": {
#                     "Service": "cloudtrail.amazonaws.com"
#                 },
#                 "Action": "s3:GetBucketAcl",
#                 "Resource": "arn:aws:s3:::itrams-dm-prod-cloudtrail-${var.main_region}"
#             },
#             {
#                 "Sid": "AWSCloudTrailWrite",
#                 "Effect": "Allow",
#                 "Principal": {
#                     "Service": "cloudtrail.amazonaws.com"
#                 },
#                 "Action": "s3:PutObject",
#                 "Resource": "arn:aws:s3:::itrams-dm-prod-cloudtrail-${var.main_region}/AWSLogs/${module.vpc.account_id}/*",
#                 "Condition": {
#                     "StringEquals": {
#                         "s3:x-amz-acl": "bucket-owner-full-control"
#                     }
#                 }
#             }
#         ]
# }
# POLICY
# }

#IAM role for cloudtrail
# resource "aws_iam_role" "cloudtrail" {
#   name               = "CloudTrail_CloudWatchLogs_Role"
#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "cloudtrail.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# EOF
# }

#IAM policy
# resource "aws_iam_role_policy" "cloudtrail" {
#   name   = "CloudTrail_CloudWatchLogs_Policy"
#   role   = aws_iam_role.cloudtrail.id
#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "AWSCloudTrailCreateLogStream",
#       "Effect": "Allow",
#       "Action": ["logs:CreateLogStream"],
#       "Resource": [
#         "arn:aws:logs:${var.main_region}:${module.vpc.account_id}:log-group:${aws_cloudwatch_log_group.cloudtrail.id}:log-stream:*"
#       ]
#     },
#     {
#       "Sid": "AWSCloudTrailPutLogEvents",
#       "Effect": "Allow",
#       "Action": ["logs:PutLogEvents"],
#       "Resource": [
#         "arn:aws:logs:${var.main_region}:${module.vpc.account_id}:log-group:${aws_cloudwatch_log_group.cloudtrail.id}:log-stream:*"
#       ]
#     }
#   ]
# }
# EOF
# }

#Cloudtrail
# resource "aws_cloudtrail" "dm" {
#   name                       = "itrams-dm-prod-cloudtrail"
#   cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
#   cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail.arn
#   is_multi_region_trail      = "true"
#   enable_log_file_validation = "true"
#   s3_bucket_name             = aws_s3_bucket.log.id
#   event_selector {
#     include_management_events = "true"
#     data_resource {
#       type   = "AWS::S3::Object"
#       values = ["arn:aws:s3:::"]
#     }
#   }
#   insight_selector {
#     insight_type = "ApiCallRateInsight"
#   }
# }

# terraform {
#   backend "s3" {
#     bucket                  = "tfstate-cummin-dev"
#     dynamodb_table          = "terraform_state_locking"
#     key                     = "terraform.tfstate"
#     region                  = "us-east-1"
#     shared_credentials_file = "C:\\terraform\\DM\\credentials"
#   }
# }