# modules/s3/main.tf
resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.prefix}-log-bucket-${random_id.bucket_suffix.hex}"
  acl    = "private"

  lifecycle_rule {
    enabled = true
    noncurrent_version_expiration {
      days = 90 # 非現行バージョンを90日後に削除
    }
    expiration {
      days = 365 # オブジェクトを365日後に削除
    }
  }

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name = "${var.prefix}-log-bucket"
  }
}

resource "aws_s3_bucket_policy" "log_bucket_policy" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = data.aws_iam_policy_document.log_bucket_policy_document.json
}

data "aws_iam_policy_document" "log_bucket_policy_document" {
  statement {
    sid = "AWSLogDeliveryWrite"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:PutObject", "s3:GetBucketAcl"]
    resources = [
      aws_s3_bucket.log_bucket.arn,
      "${aws_s3_bucket.log_bucket.arn}/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
  statement {
    sid = "AWSLogDeliveryCheck"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions = ["s3:GetBucketPolicy"]
    resources = [
      aws_s3_bucket.log_bucket.arn,
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}
