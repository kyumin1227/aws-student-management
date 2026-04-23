# 현재 AWS 계정 ID 조회 — Secrets Manager ARN에 계정 ID를 명시해 타계정 접근 방지
data "aws_caller_identity" "current" {}

locals {
  ecs_projects = { for r in var.github_repos : r.repo => r if r.ecs }

  ecs_extra_policies = flatten([
    for repo, proj in local.ecs_projects : [
      for i, policy in proj.policies : {
        key    = "${repo}:${i}"
        repo   = repo
        policy = policy
      }
    ]
  ])
}
