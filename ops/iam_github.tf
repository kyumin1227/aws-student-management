# GitHub Actions 배포 역할
#
# GitHub Actions에서 aws-actions/configure-aws-credentials@v4 로 assume.
# IAM 액세스 키 없이 OIDC 토큰으로 인증 — 키 rotation 불필요.
#
# 권한 범위:
#   - PowerUserAccess: ECS, RDS, S3, ElastiCache, VPC, ALB, CloudWatch, ECR 등 전체 관리
#   - IAMFullAccess 제외: IAM 리소스 직접 생성 불가 (ops/ Terraform 코드 통해서만 관리)
#   - PassRole: ECS tasks 서비스 전달 용도로만 허용 (Deny로 범위 제한)
#
# ✅ 의도적 선택: 100명 학과 서비스 규모에서 배포 속도 우선.
#    서비스가 안정화되면 필요한 Action만 열거하는 최소 권한 정책으로 교체 권장.

resource "aws_iam_role" "github_actions" {
  name        = "${var.app_name}-github-actions-role"
  description = "GitHub Actions OIDC deploy role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # 등록된 모든 레포에서 OIDC 인증 허용
          "token.actions.githubusercontent.com:sub" = [
            for r in var.github_repos : "repo:${r.org}/${r.repo}:*"
          ]
        }
      }
    }]
  })
}

# PowerUserAccess — ECS/RDS/S3/ElastiCache/VPC/ALB/ECR 등 AWS 서비스 전체 관리 가능
# IAM User/Role 직접 생성은 불가 (IAMFullAccess 미포함)
resource "aws_iam_role_policy_attachment" "github_poweruser" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# PassRole 범위 제한 — ECS tasks 서비스 전달 용도 외 Deny
#
# PowerUserAccess는 iam:PassRole을 포함하므로, Deny로 범위를 좁힘.
# 검증 방법:
#   aws iam simulate-principal-policy \
#     --policy-source-arn <github_actions_role_arn> \
#     --action-names iam:PassRole \
#     --resource-arns <ecs_task_role_arn> \
#     --context-entries "ContextKeyName=iam:PassedToService,ContextKeyType=string,ContextKeyValues=ecs-tasks.amazonaws.com"
resource "aws_iam_role_policy" "github_passrole" {
  name = "restrict-passrole-to-ecs"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyPassRoleToNonECS"
      Effect   = "Deny"
      Action   = "iam:PassRole"
      Resource = "*"
      Condition = {
        StringNotEquals = {
          "iam:PassedToService" = "ecs-tasks.amazonaws.com"
        }
      }
    }]
  })
}
