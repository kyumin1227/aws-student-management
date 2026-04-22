variable "app_name" {
  description = "앱 이름 — IAM 리소스 네이밍 prefix로 사용 (소문자, 하이픈 허용, 예: dept-slack-app)"
  type        = string
}

variable "aws_region" {
  description = "AWS 리전 (예: ap-northeast-2)"
  type        = string
  default     = "ap-northeast-2"
}

variable "github_repos" {
  description = "GitHub Actions OIDC 신뢰 관계를 허용할 레포 목록 (예: [{org=\"myorg\", repo=\"my-app\"}])"
  type = list(object({
    org  = string
    repo = string
  }))
}
