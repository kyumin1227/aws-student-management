variable "app_name" {
  description = "앱 이름 — IAM 리소스 네이밍 prefix로 사용 (소문자, 하이픈 허용, 예: dept-slack-app)"
  type        = string
}

variable "aws_region" {
  description = "AWS 리전 (예: ap-northeast-2)"
  type        = string
  default     = "ap-northeast-2"
}

variable "github_org" {
  description = "GitHub 조직 또는 사용자명 (OIDC 신뢰 관계에 사용, 예: my-github-org)"
  type        = string
}

variable "github_repo" {
  description = "앱 코드 GitHub 리포지토리 이름 (이 관리 레포가 아닌 슬랙 앱 레포, 예: slack-app)"
  type        = string
}
