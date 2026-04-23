variable "aws_region" {
  description = "AWS 기본 리전 — provider 설정용. 각 프로젝트는 github_repos[].region으로 개별 설정 가능"
  type        = string
  default     = "ap-northeast-2"
}

variable "github_repos" {
  description = "GitHub Actions OIDC 신뢰 관계를 허용할 레포 목록. ecs=true이면 프로젝트별 ECS 롤 생성, policies로 추가 관리형 정책 부착 가능"
  type = list(object({
    org      = string
    repo     = string
    app_name = string
    region   = optional(string, "ap-northeast-2")
    ecs      = optional(bool, false)
    policies = optional(list(string), [])
  }))
}

variable "developers" {
  description = "ops 계정 접근 권한을 부여할 개발자 목록. username은 student-lab에서 생성된 Identity Center 유저명과 일치해야 함"
  type = list(object({
    username = string
    projects = list(string)
  }))
  default = []
}
