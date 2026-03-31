resource "aws_budgets_budget" "student" {
  for_each = toset(var.students)

  name         = "student-${each.key}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(lookup(var.student_budget_limits, each.key, var.budget_limit_usd))
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # ⚠️ format() 필수:
  #   "user:Owner$${each.key}" → HCL 이스케이프로 인해 리터럴 "user:Owner${each.key}" 생성 (버그)
  #   format("user:Owner$%s", each.key) → 올바르게 "user:Owner$alice" 생성
  # 전제조건: AWS Cost Explorer에서 "Owner" 태그를 Cost Allocation Tag로 활성화해야 함
  cost_filter {
    name   = "TagKeyValue"
    values = [format("user:Owner$%s", each.key)]
  }

  # 50% — 경보 토픽 (강사 이메일)
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 50
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_warning.arn]
  }

  # 80% — 경보 토픽 (강사 이메일)
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_warning.arn]
  }

  # 100% — 킬 스위치 토픽 (Lambda + 강사 이메일)
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_kill.arn]
  }
}
