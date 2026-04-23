variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "students" {
  description = "학생 목록. username은 Identity Center 로그인 ID 및 Owner 태그 값으로 사용"
  type = list(object({
    username    = string
    given_name  = string
    family_name = string
    email       = optional(string, "")
    budget      = optional(number, null)
  }))
}

variable "budget_limit_usd" {
  description = "학생 1인당 월 예산 기본값 (USD). students[].budget으로 개별 재정의 가능"
  type        = number
  default     = 40
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
