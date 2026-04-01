# ECS Execution Role — ECS 플랫폼 시스템 권한
#
# ECS Task Definition의 `executionRoleArn`에 설정.
# ECS가 컨테이너를 시작할 때 내부적으로 사용. 앱 코드는 이 역할을 직접 사용하지 않음.
#
# 역할:
#   1. ECR에서 Docker 이미지 pull
#   2. CloudWatch Logs에 컨테이너 로그 쓰기
#   3. Secrets Manager에서 환경 변수 주입 (Task Definition secrets 필드)

resource "aws_iam_role" "ecs_execution" {
  name        = "${var.app_name}-ecs-execution-role"
  description = "ECS Execution Role for ${var.app_name} - ECR pull, CloudWatch Logs, Secrets Manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# AWS 관리형 정책: ECR pull + CloudWatch Logs 기본 권한
# 포함 내용: ecr:GetAuthorizationToken, ecr:BatchGetImage, ecr:GetDownloadUrlForLayer,
#            logs:CreateLogStream, logs:PutLogEvents
resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager 접근 — Task Definition secrets 필드를 통한 환경 변수 자동 주입
# (예: DB_PASSWORD, SLACK_BOT_TOKEN, GOOGLE_CALENDAR_CREDENTIALS)
# account_id 명시로 타계정 secret 접근 방지
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "secrets-injection"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "SecretsManagerInjection"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.app_name}/*"
    }]
  })
}
