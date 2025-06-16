# main.tf
provider "aws" {
  region = var.aws_region
}

module "oracle_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.2"

  name = "oracle-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Name = "oracle-vpc"
  }
}

resource "aws_s3_bucket" "oracle_audio" {
  bucket = var.s3_bucket_name
  force_destroy = true

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 86400
  }
}

resource "aws_acm_certificate" "oracle_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "oracle_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.oracle_cert.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  name    = each.value.name
  type    = each.value.type
  zone_id = var.route53_zone_id
  records = [each.value.value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "oracle_cert_validated" {
  certificate_arn         = aws_acm_certificate.oracle_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.oracle_cert_validation : record.fqdn]
}

resource "aws_route53_record" "oracle_alias" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.oracle_alb.dns_name
    zone_id                = aws_lb.oracle_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_s3_bucket_cors_configuration" "oracle_audio_cors" {
  bucket = aws_s3_bucket.oracle_audio.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["https://oracle.pwoodward.info"]
    expose_headers  = ["ETag"]
    max_age_seconds = 86400
  }
}

resource "aws_iam_policy" "oracle_audio_s3_access" {
  name = "oracle-audio-s3-access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = "arn:aws:s3:::oracle-audio-files-pwoodward"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:HeadObject"
        ],
        Resource = "arn:aws:s3:::oracle-audio-files-pwoodward/*"
      }
    ]
  })
}
