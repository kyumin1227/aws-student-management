# GitHub Actions OIDC Provider
# 수동으로 생성 후 data source로 참조.

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}
