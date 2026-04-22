# Developer IAM User — 로컬 개발 및 테스트용
#
# GitHub Actions OIDC Role과 완전히 별개로 동작.
#   - GitHub Actions: OIDC 토큰으로 Role assume (키 없음)
#   - Dev User: Access Key ID + Secret으로 인증 (로컬 AWS CLI/Terraform)
#
# ⚠️ Access Key는 Terraform으로 생성하지 않음.
#    state 파일에 시크릿이 평문 저장되는 보안 이슈 때문.
#    User 생성 후 AWS 콘솔 또는 CLI에서 직접 발급:
#      AWS 콘솔 → IAM → Users → {user_name} → Security credentials → Create access key

resource "aws_iam_user" "dev" {
  name = "${var.app_name}-dev"
  path = "/"
}

# GitHub Actions Role과 동일한 권한 수준
resource "aws_iam_user_policy_attachment" "dev_poweruser" {
  user       = aws_iam_user.dev.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# 콘솔 로그인 — 첫 로그인 시 비밀번호 변경 강제
resource "aws_iam_user_login_profile" "dev" {
  user                    = aws_iam_user.dev.name
  password_reset_required = true
}

# 본인 비밀번호 변경 권한
resource "aws_iam_user_policy" "dev_change_password" {
  name = "allow-self-change-password"
  user = aws_iam_user.dev.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "iam:ChangePassword",
        "iam:GetAccountPasswordPolicy",
        "iam:CreateAccessKey",
        "iam:DeleteAccessKey",
        "iam:ListAccessKeys",
        "iam:UpdateAccessKey"
      ]
      Resource = "arn:aws:iam::*:user/$${aws:username}"
    }]
  })
}

output "dev_user_initial_password" {
  description = "콘솔 초기 비밀번호 — terraform apply 직후 확인, 첫 로그인 시 변경 필요"
  value       = aws_iam_user_login_profile.dev.password
  sensitive   = true
}
