# 태그 강제 IAM 정책 (생성 시 Owner 필수 + 생성 후 제거 차단 + 고비용 리소스 차단)
resource "aws_iam_policy" "student_tag_enforce" {
  name        = "StudentTagEnforcePolicy"
  description = "학생 IAM 사용자: Owner 태그 강제 + 고비용 리소스 차단"
  policy      = file("${path.module}/policies/student_tag_enforce.json")
}

# 학생별 IAM 사용자
resource "aws_iam_user" "student" {
  for_each = toset(var.students)

  name = each.key   # "alice", "bob" 등 — aws:username == Owner 태그 값과 일치
  path = "/students/"

  tags = {
    Owner = each.key
  }
}

# 모든 학생에게 태그 강제 정책 부착
resource "aws_iam_user_policy_attachment" "student_tag_enforce" {
  for_each = toset(var.students)

  user       = aws_iam_user.student[each.key].name
  policy_arn = aws_iam_policy.student_tag_enforce.arn
}

# AWS 관리형 EC2/S3 기본 권한 부착 (실습에 필요한 서비스 접근)
resource "aws_iam_user_policy_attachment" "student_poweruser" {
  for_each = toset(var.students)

  user       = aws_iam_user.student[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# 비밀번호 변경 권한 (PowerUserAccess가 IAM 전체를 막기 때문에 별도 부착 필요)
resource "aws_iam_user_policy_attachment" "student_change_password" {
  for_each = toset(var.students)

  user       = aws_iam_user.student[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"
}

# 학생별 콘솔 로그인 비밀번호
# 첫 로그인 시 반드시 비밀번호 변경하도록 강제
resource "aws_iam_user_login_profile" "student" {
  for_each = toset(var.students)

  user                    = aws_iam_user.student[each.key].name
  password_reset_required = true
}

# 학생별 IAM 액세스 키 (AWS CLI 사용 시 필요)
resource "aws_iam_access_key" "student" {
  for_each = toset(var.students)

  user = aws_iam_user.student[each.key].name
}

# 콘솔 로그인 정보 출력
output "student_console_credentials" {
  description = "학생별 콘솔 로그인 정보 (민감 정보 — 별도 채널로 전달)"
  sensitive   = true
  value = {
    sign_in_url = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
    students = {
      for name in var.students : name => {
        username         = aws_iam_user.student[name].name
        temp_password    = aws_iam_user_login_profile.student[name].password
      }
    }
  }
}

# CLI 액세스 키 출력
output "student_access_keys" {
  description = "학생별 CLI 액세스 키 (민감 정보 — 별도 채널로 전달)"
  sensitive   = true
  value = {
    for name in var.students : name => {
      access_key_id     = aws_iam_access_key.student[name].id
      secret_access_key = aws_iam_access_key.student[name].secret
    }
  }
}
