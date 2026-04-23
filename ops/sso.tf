# IAM Identity Center — ops 계정 개발자 접근 관리
#
# 전제 조건: student-lab을 먼저 apply해 Identity Center 유저가 생성되어 있어야 함

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  sso_identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  # 프로젝트별 개발자 목록 (그룹 멤버십 생성용)
  developer_project_pairs = flatten([
    for dev in var.developers : [
      for project in dev.projects : {
        key      = "${dev.username}:${project}"
        username = dev.username
        project  = project
      }
    ]
  ])

  all_projects = toset(flatten([for dev in var.developers : dev.projects]))
}

# ─── Permission Set ────────────────────────────────────────────────────────────

resource "aws_ssoadmin_permission_set" "developer" {
  name             = "OpsDevAccess"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  description      = "Ops project developer access permission set"
}

resource "aws_ssoadmin_managed_policy_attachment" "developer_poweruser" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# ─── 기존 유저 참조 ─────────────────────────────────────────────────────────────

data "aws_identitystore_user" "developer" {
  for_each          = toset([for dev in var.developers : dev.username])
  identity_store_id = local.sso_identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = each.key
    }
  }
}

# ─── 프로젝트별 그룹 ────────────────────────────────────────────────────────────

resource "aws_identitystore_group" "project" {
  for_each          = local.all_projects
  identity_store_id = local.sso_identity_store_id
  display_name      = "Project-${each.key}"
  description       = "Developers for project ${each.key}"
}

resource "aws_identitystore_group_membership" "developer" {
  for_each          = { for pair in local.developer_project_pairs : pair.key => pair }
  identity_store_id = local.sso_identity_store_id
  group_id          = aws_identitystore_group.project[each.value.project].group_id
  member_id         = data.aws_identitystore_user.developer[each.value.username].user_id
}

# ─── 계정 배정 ─────────────────────────────────────────────────────────────────

resource "aws_ssoadmin_account_assignment" "project" {
  for_each           = local.all_projects
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn

  principal_id   = aws_identitystore_group.project[each.key].group_id
  principal_type = "GROUP"

  target_id   = data.aws_caller_identity.current.account_id
  target_type = "AWS_ACCOUNT"
}
