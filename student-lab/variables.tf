variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "students" {
  description = "학생 목록. username은 Identity Center 로그인 ID 및 Owner 태그 값으로 사용"
  type = list(object({
    username     = string
    display_name = string
    given_name   = string
    family_name  = string
    email        = optional(string, "")
    budget       = optional(number, null)
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

variable "student_lab_mode" {
  description = <<-EOT
    학생 실습 권한 모드
      restricted : 기본 제한 모드 (EC2/S3/RDS ABAC, 비용 제어)
      poweruser  : VPC·Lambda·CloudWatch 실습 (비용 제어 유지, IAM 제외)
      admin      : IAM 실습 (AdministratorAccess, 제한 없음)
  EOT
  type        = string
  default     = "restricted"
  validation {
    condition     = contains(["restricted", "poweruser", "admin"], var.student_lab_mode)
    error_message = "student_lab_mode은 restricted, poweruser, admin 중 하나여야 합니다."
  }
}
