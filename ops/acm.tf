# Route 53 호스팅 존 참조 (Route 53에서 도메인 구입 시 자동 생성됨)
data "aws_route53_zone" "main" {
  name         = "gsc-lab.io"
  private_zone = false
}

# 와일드카드 인증서 — *.gsc-lab.io + gsc-lab.io 동시 커버
resource "aws_acm_certificate" "main" {
  domain_name               = "gsc-lab.io"
  subject_alternative_names = ["*.gsc-lab.io"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# DNS 검증 레코드 자동 생성
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

# 검증 완료 대기 — 이후 리소스에서 certificate_arn 참조 가능
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
