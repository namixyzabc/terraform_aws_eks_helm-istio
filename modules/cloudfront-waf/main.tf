# modules/cloudfront-waf/main.tf
data "aws_wafv2_ip_set" "aws_managed_ips_amazon" {
  name  = "AWS-AWSManagedIPsAmazon"
  scope = "CLOUDFRONT"
}

data "aws_wafv2_managed_rule_group" "aws_managed_rules_common_rule_set" {
  name  = "AWSManagedRulesCommonRuleSet"
  scope = "CLOUDFRONT"
}

data "aws_wafv2_managed_rule_group" "aws_managed_rules_sql_injection_rule_set" {
  name  = "AWSManagedRulesSQLInjectionRuleSet"
  scope = "CLOUDFRONT"
}

data "aws_wafv2_managed_rule_group" "aws_managed_rules_xss_injection_rule_set" {
  name  = "AWSManagedRulesXSSInjectionRuleSet"
  scope = "CLOUDFRONT"
}


resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name              = var.origin_domain_name # ALB の DNS 名などを設定
    origin_id                = "eks-alb"
    origin_path              = "/"

    custom_header {
      name  = "X-Custom-Origin-Header"
      value = "my-secret-value" # 必要に応じてカスタムヘッダーを設定
    }

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols    = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  price_class         = var.cloudfront_price_class
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "eks-alb"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
      headers = ["Origin"] # 必要に応じてヘッダーをフォワード
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  ordered_cache_behavior { # 例：特定のパスでキャッシュ設定を変える場合
    path_pattern         = "/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "eks-alb"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    min_ttl     = 86400
    default_ttl = 86400
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none" # 必要に応じて地理的制限を設定 (whitelist, blacklist)
      locations        = [] # 例: ["US", "CA", "GB"]
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.acm_certificate_arn # ACM証明書のARNを指定
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  http_version = "http2and3"
  is_http2_enabled = true
  is_http3_enabled = true

  web_acl_id = aws_wafv2_web_acl.waf.arn # WAF Web ACL を関連付け

  tags = {
    Name = "${var.prefix}-cdn"
  }
}


resource "aws_wafv2_web_acl" "waf" {
  name  = "${var.prefix}-waf-acl"
  scope = "CLOUDFRONT"
  default_action {
    allow {}
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "cloudfront-waf-metric"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWS-ManagedRulesCommonRuleSet"
    priority = 10
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet-Metric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-ManagedRulesSQLInjectionRuleSet"
    priority = 20
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLInjectionRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLInjectionRuleSet-Metric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-ManagedRulesXSSInjectionRuleSet"
    priority = 30
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesXSSInjectionRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "XSSInjectionRuleSet-Metric"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "${var.prefix}-waf"
  }
}
