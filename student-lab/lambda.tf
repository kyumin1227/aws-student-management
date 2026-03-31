locals {
  lambda_zip_path = "${path.module}/lambda/kill_switch.zip"
}

# Lambda 코드 아카이브
data "archive_file" "kill_switch" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = local.lambda_zip_path
}

# ─── Dead Letter Queue ─────────────────────────────────────────────────────────

resource "aws_sqs_queue" "lambda_dlq" {
  name                       = "student-kill-switch-dlq"
  message_retention_seconds  = 1209600 # 14일
  kms_master_key_id          = "alias/aws/sqs"

  tags = {
    Name = "student-kill-switch-dlq"
  }
}

# DLQ에 메시지 쌓이면 CloudWatch 알림
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "student-kill-switch-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Lambda 킬 스위치 DLQ에 처리 실패 메시지가 있습니다."
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.lambda_dlq.name
  }
}

# ─── Lambda IAM 역할 ───────────────────────────────────────────────────────────

resource "aws_iam_role" "lambda_kill_switch" {
  name = "lambda-student-kill-switch"

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

resource "aws_iam_role_policy" "lambda_kill_switch" {
  name = "lambda-student-kill-switch-policy"
  role = aws_iam_role.lambda_kill_switch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      # EC2: Stop + EIP 해제
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StopInstances",
          "ec2:DescribeAddresses",
          "ec2:DisassociateAddress",
          "ec2:ReleaseAddress"
        ]
        Resource = "*"
      },
      # S3: 태그 조회 + Public Access Block + Deny 정책 추가
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketTagging",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy"
        ]
        Resource = "*"
      },
      # RDS: Stop (미래 확장)
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:ListTagsForResource",
          "rds:StopDBInstance"
        ]
        Resource = "*"
      },
      # SQS DLQ 쓰기
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.lambda_dlq.arn
      },
      # SES 이메일 알림 (TODO 2)
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail"]
        Resource = "*"
      }
    ]
  })
}

# ─── Lambda 함수 ───────────────────────────────────────────────────────────────

resource "aws_lambda_function" "kill_switch" {
  function_name = "student-budget-kill-switch"
  role          = aws_iam_role.lambda_kill_switch.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256

  filename         = local.lambda_zip_path
  source_code_hash = data.archive_file.kill_switch.output_base64sha256

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  environment {
    variables = {
      # TODO 2: 학생 이메일 맵 (JSON 직렬화)
      STUDENT_EMAILS  = jsonencode(var.student_emails)
      SES_SENDER      = var.ses_sender_email
    }
  }

  tags = {
    Name = "student-budget-kill-switch"
  }

  depends_on = [data.archive_file.kill_switch]
}

# SNS가 Lambda를 호출할 권한
resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.kill_switch.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.budget_kill.arn
}
