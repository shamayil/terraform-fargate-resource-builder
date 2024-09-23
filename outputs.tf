resource "aws_ssm_parameter" "sqs" {
  for_each = toset(var.sqs_list)
  name     = "/${var.project}/${var.environment}/${var.service_name}/${each.value}/sqs/url"
  type     = "String"
  value    = aws_sqs_queue.main[each.value].name
}

resource "aws_ssm_parameter" "sqs_full_url" {
  for_each = toset(var.sqs_list)
  name     = "/${var.project}/${var.environment}/${var.service_name}/${each.value}/sqs/full_url"
  type     = "String"
  value    = aws_sqs_queue.main[each.value].url
}

resource "aws_ssm_parameter" "cluster_arn" {
  name  = "/${var.project}/${var.environment}/ecs/clusterarn"
  type  = "String"
  value = aws_ecs_cluster.main.arn
}

resource "aws_ssm_parameter" "cluster_name" {
  name  = "/${var.project}/${var.environment}/ecs/clustername"
  type  = "String"
  value = aws_ecs_cluster.main.name
}

resource "aws_ssm_parameter" "ecs_sg" {
  name  = "/${var.project}/${var.environment}/ecs/securitygroupid"
  type  = "String"
  value = aws_security_group.ecs_cluster.id
}

# create task execution role
#resource "aws_ssm_parameter" "task_execution_role" {
#  name  = "/ecs/taskexecutionrolearn"
#  type  = "String"
#  value = data.aws_iam_role.ecs_task_execution_role.arn
#}
