data "aws_iam_policy_document" "student_merged" {
  source_policy_documents = [
    file("${path.module}/policies/ec2.json"),
    file("${path.module}/policies/common_deny.json"),
  ]
}

resource "aws_iam_policy" "student_tag_enforce" {
  name        = "StudentTagEnforcePolicy"
  description = "학생 IAM 사용자: Owner 태그 강제 + 고비용 리소스 차단"
  policy      = data.aws_iam_policy_document.student_merged.json
}
