# 이 output 값들을 앱 레포의 GitHub Actions Variables에 등록하거나
# 앱 인프라 Terraform에서 참조해서 사용

output "github_actions_role_arn" {
  description = "GitHub Actions workflow에서 assume할 IAM Role ARN (AWS_DEPLOY_ROLE_ARN 변수로 등록)"
  value       = aws_iam_role.github_actions.arn
}

output "ecs_task_role_arns" {
  description = "프로젝트별 ECS Task Role ARN 맵 (repo명 → ARN)"
  value       = { for repo, role in aws_iam_role.ecs_task : repo => role.arn }
}

output "ecs_execution_role_arns" {
  description = "프로젝트별 ECS Execution Role ARN 맵 (repo명 → ARN)"
  value       = { for repo, role in aws_iam_role.ecs_execution : repo => role.arn }
}

output "account_id" {
  description = "현재 AWS 계정 ID"
  value       = data.aws_caller_identity.current.account_id
}
