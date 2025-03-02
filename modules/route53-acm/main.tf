# modules/route53-acm/main.tf
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_acm_certificate" "cert" {
  domain_name               = "${var.subdomain_name}.${aws_route53_zone.main.name}"
  validation_method         = "DNS"
  subject_alternative_names = ["*.${var.subdomain_name}.${aws_route53_zone.main.name}"]

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  name    = aws_acm_certificate.cert.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options[0].resource_record_type
  zone_id = aws_route53_zone.main.zone_id
  records = [aws_acm_certificate.cert.domain_validation_options[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]

  depends_on = [aws_route53_record.cert_validation]
}
