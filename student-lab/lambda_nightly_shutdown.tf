# 매일 18:00(KST)에 실행 중인 EC2/RDS를 자동 중지.
# Environment=production 태그가 붙은 리소스는 예외 처리.

locals {
  nightly_shutdown_zip_path = "${path.module}/lambda/nightly_shutdown.zip"
}

data "archive_file" "nightly_shutdown" {
  type        = "zip"
  source_file = "${path.module}/lambda/nightly_shutdown/index.py"
  output_path = local.nightly_shutdown_zip_path
}

# ─── Lambda IAM 역할 ───────────────────────────────────────────────────────────

resource "aws_iam_role" "lambda_nightly_shutdown" {
  name = "lambda-student-nightly-shutdown"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_nightly_shutdown" {
  name = "lambda-student-nightly-shutdown-policy"
  role = aws_iam_role.lambda_nightly_shutdown.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StopInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:ListTagsForResource",
          "rds:StopDBInstance"
        ]
        Resource = "*"
      }
    ]
  })
}

# ─── Lambda 함수 ───────────────────────────────────────────────────────────────

resource "aws_lambda_function" "nightly_shutdown" {
  function_name = "student-nightly-shutdown"
  role          = aws_iam_role.lambda_nightly_shutdown.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60
  memory_size   = 256

  filename         = local.nightly_shutdown_zip_path
  source_code_hash = data.archive_file.nightly_shutdown.output_base64sha256

  tags = {
    Name = "student-nightly-shutdown"
  }

  depends_on = [data.archive_file.nightly_shutdown]
}

# ─── EventBridge 스케줄 (매일 18:00 KST = 09:00 UTC) ───────────────────────────

resource "aws_cloudwatch_event_rule" "nightly_shutdown" {
  name                = "student-nightly-shutdown"
  description         = "매일 18:00(KST) 비운영 EC2/RDS 자동 중지"
  schedule_expression = "cron(0 9 * * ? *)"
}

resource "aws_cloudwatch_event_target" "nightly_shutdown" {
  rule = aws_cloudwatch_event_rule.nightly_shutdown.name
  arn  = aws_lambda_function.nightly_shutdown.arn
}

resource "aws_lambda_permission" "eventbridge_invoke_nightly_shutdown" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.nightly_shutdown.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.nightly_shutdown.arn
}
