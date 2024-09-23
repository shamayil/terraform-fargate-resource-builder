## Data ssm_paramter ##
data "aws_ssm_parameter" "vpc_id" {
  name = "/vpc/id"
}

data "aws_ssm_parameter" "public_subnet_1" {
  name = "/vpc/publicsubnet1"
}

data "aws_ssm_parameter" "public_subnet_2" {
  name = "/vpc/publicsubnet2"
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

## Data resources ##
data "aws_vpc" "main" {
  id = data.aws_ssm_parameter.vpc_id.value
}

## Resource ECS ##
resource "aws_security_group" "ecs_cluster" {
  name        = "${var.project}-${var.environment}-cluster"
  description = "${var.project}-${var.environment}-cluster"
  vpc_id      = data.aws_vpc.main.id

  tags = {
    Name        = "${var.project}-${var.environment}-cluster"
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_cluster_main_ingress" {
  security_group_id = aws_security_group.ecs_cluster.id
  cidr_ipv4         = data.aws_vpc.main.cidr_block
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "ecs_cluster_main_egress" {
  security_group_id = aws_security_group.ecs_cluster.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-cluster"
    Environment = var.environment
  }
}

resource "aws_iam_role" "main" {
  count               = length(data.aws_iam_role.ecs_task_execution_role.arn) == 0 ? 1 : 0
  name                = "ecsTaskExecutionRole"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite", # Note: Need to limit permission
    "arn:aws:iam::aws:policy/CloudWatchFullAccess",
    aws_iam_policy.main[0].arn
  ]

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name        = "ecsTaskExecutionRole"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "main" {
  count       = length(data.aws_iam_role.ecs_task_execution_role.arn) == 0 ? 1 : 0
  name        = "${var.project}-${var.environment}-internal-services"
  description = "${var.project}-${var.environment}-internal-services"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = [
          "execute-api:*",
          "sns:*",
          "apigateway:*",
          "dynamodb:*",
          "s3:*",
          "sqs:*",
          "ses:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-internal-services"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  count      = length(data.aws_iam_role.ecs_task_execution_role.arn) == 0 ? 1 : 0
  role       = aws_iam_role.main[0].name
  policy_arn = aws_iam_policy.main[0].arn
}


## Resource ECR ##
resource "aws_ecr_repository" "main" {
  name                 = "${var.project}-${var.environment}-${var.service_name}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project}-${var.environment}-${var.service_name}"
    Environment = var.environment
  }
}

# Resource SQS ##
resource "aws_sqs_queue" "main" {
  for_each                   = toset(var.sqs_list)
  name                       = "${var.project}-${var.environment}-${var.service_name}-${each.value}"
  visibility_timeout_seconds = 60
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 14400
  receive_wait_time_seconds  = 0
  sqs_managed_sse_enabled    = false

  tags = {
    Name        = "${var.project}-${var.environment}-${var.service_name}"
    Environment = var.environment
  }
}

## Resource EFS ##
#resource "aws_efs_file_system" "main" {
#  creation_token   = "${var.project}-${var.environment}-${var.service_name}"
#  performance_mode = "generalPurpose"
#  throughput_mode  = "elastic"
#  encrypted        = true
#  lifecycle_policy {
#    transition_to_ia = "AFTER_30_DAYS"
#  }
#  lifecycle_policy {
#    transition_to_archive = "AFTER_90_DAYS"
#  }
#
#  protection {
#    replication_overwrite = "ENABLED"
#  }
#
#  tags = {
#    Name        = "${var.project}-${var.environment}-${var.service_name}"
#    Environment = var.environment
#  }
#}
#
#resource "aws_efs_access_point" "main" {
#  file_system_id = aws_efs_file_system.main.id
#  posix_user {
#    gid            = 1000
#    uid            = 1000
#    secondary_gids = [1000]
#  }
#  root_directory {
#    path = "/storage"
#    creation_info {
#      owner_gid   = 1000
#      owner_uid   = 1000
#      permissions = "777"
#    }
#  }
#  tags = {
#    Name        = "${var.project}-${var.environment}-${var.service_name}"
#    Environment = var.environment
#  }
#}
#
#resource "aws_efs_mount_target" "primary" {
#  file_system_id  = aws_efs_file_system.main.id
#  subnet_id       = data.aws_ssm_parameter.public_subnet_1.value
#  security_groups = [aws_security_group.efs.id]
#}
#
#resource "aws_efs_mount_target" "secondary" {
#  file_system_id  = aws_efs_file_system.main.id
#  subnet_id       = data.aws_ssm_parameter.public_subnet_2.value
#  security_groups = [aws_security_group.efs.id]
#}
#
### EFS Security group ##
#resource "aws_security_group" "efs" {
#  name        = "${var.project}-${var.environment}-efs"
#  description = "${var.project}-${var.environment}-efs"
#  vpc_id      = data.aws_vpc.main.id
#
#  tags = {
#    Name        = "${var.project}-${var.environment}-efs"
#    Environment = var.environment
#  }
#}
#
#resource "aws_vpc_security_group_ingress_rule" "efs_main_ingress" {
#  security_group_id = aws_security_group.efs.id
#  cidr_ipv4         = data.aws_vpc.main.cidr_block
#  from_port         = 2049
#  ip_protocol       = "TCP"
#  to_port           = 2049
#}
#
#resource "aws_vpc_security_group_egress_rule" "efs_main_egress" {
#  security_group_id = aws_security_group.efs.id
#  cidr_ipv4         = "0.0.0.0/0"
#  ip_protocol       = "-1"
#}
