output "sso_portal_url" {
  description = "학생 SSO 로그인 포털 URL"
  value       = "https://d-${local.sso_identity_store_id}.awsapps.com/start"
}

output "student_usernames" {
  description = "학생별 Identity Center 사용자명"
  value       = { for s in var.students : s.username => aws_identitystore_user.student[s.username].user_name }
}

output "sns_warning_topic_arn" {
  description = "Budget 50%/80% 경보 SNS 토픽 ARN"
  value       = aws_sns_topic.budget_warning.arn
}

output "sns_kill_topic_arn" {
  description = "Budget 100% 킬 스위치 SNS 토픽 ARN"
  value       = aws_sns_topic.budget_kill.arn
}

output "lambda_function_name" {
  description = "킬 스위치 Lambda 함수 이름"
  value       = aws_lambda_function.kill_switch.function_name
}

output "dlq_url" {
  description = "Lambda DLQ URL (파싱 실패 메시지 모니터링용)"
  value       = aws_sqs_queue.lambda_dlq.url
}
