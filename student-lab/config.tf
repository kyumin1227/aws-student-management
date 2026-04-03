# AWS Config — Owner 태그 누락 리소스 감지
#
# Config 비용: 리소스 기록 건당 $0.003, 규칙 평가 건당 $0.001
# 실습 환경 규모에서는 월 $1~2 수준

# ─── Config IAM 역할 ───────────────────────────────────────────────────────────

resource "aws_iam_role" "config" {
  name = "student-lab-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Config → CloudTrail S3 버킷에 스냅샷 저장
resource "aws_iam_role_policy" "config_s3" {
  name = "student-lab-config-s3"
  role = aws_iam_role.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# ─── Config Recorder ──────────────────────────────────────────────────────────

resource "aws_config_configuration_recorder" "student_lab" {
  name     = "student-lab-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = false
    include_global_resource_types = false

    recording_strategy {
      use_only = "EXCLUSION_BY_RESOURCE_TYPES"
    }

    exclusion_by_resource_types {
      resource_types = [
        "AWS::IAM::Role",
        "AWS::IAM::User",
        "AWS::IAM::Policy",
        "AWS::IAM::Group",
        "AWS::EC2::Volume",
        "AWS::EC2::Subnet",
        "AWS::EC2::VPC",
        "AWS::EC2::VPCEndpoint",
        "AWS::EC2::NetworkInterface",
        "AWS::EC2::NetworkAcl",
        "AWS::EC2::RouteTable",
        "AWS::EC2::InternetGateway",
        "AWS::EC2::SecurityGroup",
        "AWS::RDS::DBSubnetGroup",
        "AWS::RDS::DBSnapshot",
        "AWS::CloudTrail::Trail",
        "AWS::Config::ResourceCompliance",
      ]
    }
  }
}

resource "aws_config_delivery_channel" "student_lab" {
  name           = "student-lab-delivery-channel"
  s3_bucket_name = aws_s3_bucket.cloudtrail.bucket

  depends_on = [aws_config_configuration_recorder.student_lab]
}

resource "aws_config_configuration_recorder_status" "student_lab" {
  name       = aws_config_configuration_recorder.student_lab.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.student_lab]
}

# ─── required-tags 규칙 ────────────────────────────────────────────────────────

resource "aws_config_config_rule" "required_owner_tag" {
  name = "student-lab-required-owner-tag"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    tag1Key = "Owner"
  })

  depends_on = [aws_config_configuration_recorder_status.student_lab]
}

# ─── EventBridge → SNS 알림 ────────────────────────────────────────────────────

# Config 규칙 비준수 이벤트 → config_alert SNS 토픽으로 알림
resource "aws_cloudwatch_event_rule" "config_noncompliant" {
  name        = "student-lab-config-noncompliant"
  description = "Owner 태그 없는 리소스 감지 시 관리자 알림"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName = [aws_config_config_rule.required_owner_tag.name]
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "config_noncompliant_sns" {
  rule      = aws_cloudwatch_event_rule.config_noncompliant.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.config_alert.arn

  input_transformer {
    input_paths = {
      resource    = "$.detail.resourceId"
      type        = "$.detail.resourceType"
      rule        = "$.detail.configRuleName"
      time        = "$.time"
    }
    input_template = "\"[AWS Lab] Owner 태그 누락 감지\\n리소스 타입: <type>\\n리소스 ID: <resource>\\n감지 시각: <time>\\n\\n해당 학생에게 Owner 태그 추가를 안내하세요.\""
  }
}
