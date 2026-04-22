# IAM 리소스 이름 prefix (소문자, 숫자, 하이픈만 허용)
app_name = "gsc-slack-app-test"

# AWS 리전 — 서울 리전 기본값
aws_region = "ap-northeast-2"

# GitHub OIDC 신뢰 관계 설정 — 여러 레포 추가 가능
github_repos = [
  { org = "kyumin1227", repo = "gsc-slack-app" },
]
