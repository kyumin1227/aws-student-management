resource "aws_iam_policy" "student_ec2" {
  name        = "StudentEC2Policy"
  description = "학생 EC2 권한 (Owner 태그 기반 격리)"
  policy      = file("${path.module}/policies/ec2.json")
}

resource "aws_iam_policy" "student_s3" {
  name        = "StudentS3Policy"
  description = "학생 S3 권한 (버킷 이름 prefix 기반 격리)"
  policy      = file("${path.module}/policies/s3.json")
}

resource "aws_iam_policy" "student_rds" {
  name        = "StudentRDSPolicy"
  description = "학생 RDS 권한 (Owner 태그 기반 격리)"
  policy      = file("${path.module}/policies/rds.json")
}

resource "aws_iam_policy" "student_deny" {
  name        = "StudentDenyPolicy"
  description = "학생 고비용 리소스 차단 및 리전 제한"
  policy      = file("${path.module}/policies/common_deny.json")
}
