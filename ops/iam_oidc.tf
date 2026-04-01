# GitHub Actions OIDC Provider
#
# AWS 계정당 동일 URL의 OIDC Provider는 1개만 생성 가능.
# ✅ 결정: ops/가 이 Provider를 소유. student-lab에서는 절대 생성하지 않음.
#
# 미래에 다른 앱도 GitHub Actions를 쓰게 되면 해당 앱의 Terraform에서
# resource 대신 data source로 참조:
#   data "aws_iam_openid_connect_provider" "github" {
#     url = "https://token.actions.githubusercontent.com"
#   }

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS는 2023년 이후 생성된 GitHub OIDC Provider에 대해 thumbprint를 자동 검증함.
  # 아래 값은 현재(2026년) 정확한 값이나, GitHub이 CA를 rotate하면 업데이트 필요.
  # apply 후 `aws iam get-open-id-connect-provider --open-id-connect-provider-arn <arn>`
  # 으로 Provider가 정상 생성되었는지 확인 권장.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}
