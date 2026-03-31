# 50%, 80% 알림용 토픽 (강사 이메일만 구독)
resource "aws_sns_topic" "budget_warning" {
  name = "student-budget-warning"

  tags = {
    Name = "student-budget-warning"
  }
}

resource "aws_sns_topic_policy" "budget_warning" {
  arn = aws_sns_topic.budget_warning.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowBudgetsToPublish"
      Effect    = "Allow"
      Principal = { Service = "budgets.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.budget_warning.arn
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "warning_email" {
  count = var.lab_admin_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.budget_warning.arn
  protocol  = "email"
  endpoint  = var.lab_admin_email
}

# 100% 알림용 토픽 (Lambda 킬 스위치 + 강사 이메일 구독)
resource "aws_sns_topic" "budget_kill" {
  name = "student-budget-kill"

  tags = {
    Name = "student-budget-kill"
  }
}

resource "aws_sns_topic_policy" "budget_kill" {
  arn = aws_sns_topic.budget_kill.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowBudgetsToPublish"
      Effect    = "Allow"
      Principal = { Service = "budgets.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.budget_kill.arn
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

# SNS → Lambda 킬 스위치
resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.budget_kill.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.kill_switch.arn
}

resource "aws_sns_topic_subscription" "kill_email" {
  count = var.lab_admin_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.budget_kill.arn
  protocol  = "email"
  endpoint  = var.lab_admin_email
}
