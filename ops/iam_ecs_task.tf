# ECS Task Role — 앱 컨테이너의 런타임 AWS API 접근 권한
#
# ECS Task Definition의 `taskRoleArn`에 설정.
# 앱 코드가 boto3/AWS SDK로 S3, Secrets Manager 등을 호출할 때 이 역할을 사용.
#
# RDS(PostgreSQL), ElastiCache(Redis)는 여기 없어도 됨:
#   → VPC 프라이빗 서브넷 + 보안 그룹으로 네트워크 레벨 격리.
#   → DB 비밀번호는 Secrets Manager에 저장 후 이 역할로 읽어서 환경 변수 주입.

resource "aws_iam_role" "ecs_task" {
  name        = "${var.app_name}-ecs-task-role"
  description = "ECS Task Role for ${var.app_name} - app container runtime permissions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "task-permissions"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # S3: 앱 데이터 버킷 접근 (첨부파일, 내보내기 등)
        # 버킷명이 확정되면 와일드카드를 정확한 ARN으로 교체 권장
        Sid    = "S3AppBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.app_name}-*",
          "arn:aws:s3:::${var.app_name}-*/*",
        ]
      },
      {
        # Secrets Manager: DB 비밀번호, Slack API 토큰, Google Calendar 자격증명 등
        # account_id 명시로 타계정 secret 접근 방지
        Sid    = "SecretsManagerReadOnly"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.app_name}/*"
      },
    ]
  })
}
