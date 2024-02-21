# Terraform Remote State Management Resources
# This may be better to provision via AFT, if you have that stood up

resource "aws_dynamodb_table" "terraform_state_lock" {
  #checkov:skip=CKV2_AWS_16:Auto-scaling is unnecessary for this tiny table
  #checkov:skip=CKV_AWS_119:AWS-managed encryption is sufficient unless there are stricter compliance requirements
  name           = "tf-state-lock"
  hash_key       = "LockID"
  read_capacity  = 2
  write_capacity = 2
  point_in_time_recovery {
    enabled = true
  }
  server_side_encryption {
    enabled = true
    # If no kms_key_arn specified, will default to KMS-managed key alias/aws/dynamodb
    # kms_key_arn = "your arn here"
  }

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "Terraform State Lock Table"
    terraform = "True"
  }

  lifecycle {
    ignore_changes = [
      tags["AutoTag_ClientInfo"],
      tags["AutoTag_CreateTime"],
      tags["AutoTag_Creator"],
      tags["AutoTag_UserIdentityType"],
    ]
  }
}

resource "aws_s3_bucket" "tf_remote_state_bucket" {
  #checkov:skip=CKV_AWS_18:access logging is unnecessary, no sensitive data stored here
  #checkov:skip=CKV_AWS_144:cross-region replication is unnecessary here
  #checkov:skip=CKV_AWS_145:AWS-managed encryption is sufficient here
  #checkov:skip=CKV2_AWS_62:event notifications are unnecessary here
  #checkov:skip=CKV2_AWS_61:lifecycle configuration is present
  bucket = "${data.aws_caller_identity.current.account_id}-tf-remote-state"
  tags = {
    terraform = "True"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags["AutoTag_ClientInfo"],
      tags["AutoTag_CreateTime"],
      tags["AutoTag_Creator"],
      tags["AutoTag_UserIdentityType"],
    ]
  }
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.tf_remote_state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tf_remote_state_bucket_versioning" {
  bucket = aws_s3_bucket.tf_remote_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "use_aws_managed_kms_key" {
  bucket = aws_s3_bucket.tf_remote_state_bucket.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
