# 태그 강제 IAM 정책 (생성 시 Owner 필수 + 생성 후 제거 차단 + 고비용 리소스 차단)
resource "aws_iam_policy" "student_tag_enforce" {
  name        = "StudentTagEnforcePolicy"
  description = "학생 IAM 사용자: Owner 태그 강제 + 고비용 리소스 차단"
  policy      = file("${path.module}/policies/student_tag_enforce.json")
}
