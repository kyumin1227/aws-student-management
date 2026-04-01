# 현재 AWS 계정 ID 조회 — Secrets Manager ARN에 계정 ID를 명시해 타계정 접근 방지
data "aws_caller_identity" "current" {}
