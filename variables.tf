variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "students" {
  description = "학생 이름 목록 (IAM username 및 Owner 태그 값으로 사용)"
  type        = list(string)
  default = [
    "alice", "bob", "carol", "dave",
    "eve", "frank", "grace", "henry",
    "iris", "jack", "kate", "liam"
  ]
}

variable "budget_limit_usd" {
  description = "학생 1인당 월 예산 기본값 (USD). student_budget_limits로 개별 재정의 가능"
  type        = number
  default     = 40
}

variable "student_budget_limits" {
  description = "학생별 개별 예산 한도 (USD). 명시된 학생만 기본값에서 재정의됨"
  type        = map(number)
  default     = {
    "alice" = 0.01
  }
  # 예시: alice만 $60, bob만 $20으로 변경
  # default = {
  #   "alice" = 60
  #   "bob"   = 20
  # }
}

# TODO 2: 킬 스위치 발동 시 학생 이메일 알림
variable "student_emails" {
  description = "학생별 이메일 주소 맵 (킬 스위치 발동 시 알림용). 비워두면 알림 비활성화"
  type        = map(string)
  default     = {}
  # 예시:
  # default = {
  #   "alice" = "alice@example.com"
  #   "bob"   = "bob@example.com"
  # }
}

variable "ses_sender_email" {
  description = "SES 발신자 이메일 주소 (SES에서 인증된 이메일이어야 함)"
  type        = string
  default     = ""
}

variable "lab_admin_email" {
  description = "Budget 알림을 받을 강사 이메일 주소"
  type        = string
  default     = ""
}
