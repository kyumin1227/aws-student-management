output "iam_user_arns" {
  description = "학생별 IAM 사용자 ARN"
  value = {
    for name, user in aws_iam_user.student :
    name => user.arn
  }
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
