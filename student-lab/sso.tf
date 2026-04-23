# IAM Identity Center (SSO) — 학생 계정 관리
#
# 사전 준비 (콘솔에서 1회 수동 설정):
#   1. IAM Identity Center 활성화
#   2. Settings → Attributes for access control → 속성 추가:
#      Key: userName  /  Value: ${user:userName}
#      → 로그인 시 aws:PrincipalTag/userName 으로 사용자명이 전달됨

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  sso_identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

# ─── Permission Set ────────────────────────────────────────────────────────────

resource "aws_ssoadmin_permission_set" "student" {
  name             = "StudentLabAccess"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  description      = "Student lab access permission set"
}

resource "aws_ssoadmin_managed_policy_attachment" "student_poweruser" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.student.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_ssoadmin_customer_managed_policy_attachment" "student_tag_enforce" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.student.arn

  customer_managed_policy_reference {
    name = aws_iam_policy.student_tag_enforce.name
  }
}

# ─── Identity Center 유저 ──────────────────────────────────────────────────────

resource "aws_identitystore_user" "student" {
  for_each          = { for s in var.students : s.username => s }
  identity_store_id = local.sso_identity_store_id

  user_name    = each.value.username
  display_name = "${each.value.given_name} ${each.value.family_name}"

  name {
    given_name  = each.value.given_name
    family_name = each.value.family_name
  }

  emails {
    value   = each.value.email != "" ? each.value.email : "${each.value.username}@student.local"
    primary = true
    type    = "work"
  }
}

# ─── 그룹 ─────────────────────────────────────────────────────────────────────

resource "aws_identitystore_group" "students" {
  identity_store_id = local.sso_identity_store_id
  display_name      = "Students"
  description       = "Student lab users"
}

resource "aws_identitystore_group_membership" "student" {
  for_each          = { for s in var.students : s.username => s }
  identity_store_id = local.sso_identity_store_id
  group_id          = aws_identitystore_group.students.group_id
  member_id         = aws_identitystore_user.student[each.value.username].user_id
}

# ─── 계정 배정 ─────────────────────────────────────────────────────────────────

resource "aws_ssoadmin_account_assignment" "students" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.student.arn

  principal_id   = aws_identitystore_group.students.group_id
  principal_type = "GROUP"

  target_id   = data.aws_caller_identity.current.account_id
  target_type = "AWS_ACCOUNT"
}
