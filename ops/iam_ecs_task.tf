# ECS Task Role — 앱 컨테이너의 런타임 AWS API 접근 권한
#
# ECS Task Definition의 `taskRoleArn`에 설정.
# 앱 코드가 boto3/AWS SDK로 S3, Secrets Manager 등을 호출할 때 이 역할을 사용.

resource "aws_iam_role" "ecs_task" {
  for_each    = local.ecs_projects
  name        = "${each.value.app_name}-ecs-task-role"
  description = "ECS Task Role for ${each.value.app_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_base" {
  for_each = local.ecs_projects
  name     = "task-base-permissions"
  role     = aws_iam_role.ecs_task[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3AppBucketAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${each.value.app_name}-*",
          "arn:aws:s3:::${each.value.app_name}-*/*",
        ]
      },
      {
        Sid      = "SecretsManagerReadOnly"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${each.value.region}:${data.aws_caller_identity.current.account_id}:secret:${each.value.app_name}/*"
      },
    ]
  })
}

# 프로젝트별 추가 관리형 정책 (policies 필드에 지정한 경우)
resource "aws_iam_role_policy_attachment" "ecs_task_extra" {
  for_each   = { for pair in local.ecs_extra_policies : pair.key => pair }
  role       = aws_iam_role.ecs_task[each.value.repo].name
  policy_arn = each.value.policy
}
