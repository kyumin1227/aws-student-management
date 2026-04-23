# ECS Execution Role — ECS 플랫폼 시스템 권한
#
# ECS Task Definition의 `executionRoleArn`에 설정.
# ECS가 컨테이너를 시작할 때 내부적으로 사용. 앱 코드는 이 역할을 직접 사용하지 않음.

resource "aws_iam_role" "ecs_execution" {
  for_each    = local.ecs_projects
  name        = "${each.value.app_name}-ecs-execution-role"
  description = "ECS Execution Role for ${each.value.app_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  for_each   = local.ecs_projects
  role       = aws_iam_role.ecs_execution[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_logs" {
  for_each = local.ecs_projects
  name     = "cloudwatch-logs"
  role     = aws_iam_role.ecs_execution[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "CloudWatchLogsCreateGroup"
      Effect   = "Allow"
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:aws:logs:${each.value.region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${each.value.app_name}*"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  for_each = local.ecs_projects
  name     = "secrets-injection"
  role     = aws_iam_role.ecs_execution[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SecretsManagerInjection"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:${each.value.region}:${data.aws_caller_identity.current.account_id}:secret:${each.value.app_name}/*"
    }]
  })
}
