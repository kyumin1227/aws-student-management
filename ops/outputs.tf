# 이 output 값들을 앱 레포의 GitHub Actions Variables에 등록하거나
# 앱 인프라 Terraform에서 참조해서 사용

output "github_actions_role_arn" {
  description = "GitHub Actions workflow에서 assume할 IAM Role ARN (AWS_DEPLOY_ROLE_ARN 변수로 등록)"
  value       = aws_iam_role.github_actions.arn
}

output "ecs_task_role_arn" {
  description = "ECS Task Definition의 taskRoleArn에 설정 — 앱 컨테이너의 AWS API 접근 권한"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_execution_role_arn" {
  description = "ECS Task Definition의 executionRoleArn에 설정 — ECR 이미지 pull, CloudWatch 로그 쓰기"
  value       = aws_iam_role.ecs_execution.arn
}

output "account_id" {
  description = "현재 AWS 계정 ID"
  value       = data.aws_caller_identity.current.account_id
}

output "dev_user_name" {
  description = "로컬 개발용 IAM User 이름 — 콘솔에서 Access Key 발급 후 로컬 AWS CLI에 설정"
  value       = aws_iam_user.dev.name
}
