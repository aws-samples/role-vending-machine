# Module naming convention is <repoName-accountName>
module "example_security_inf_repo_Production" {
  source                   = "../github-workflow-roles"
  github_organization_name = var.github_organization_name

  # Providers block is used to indicate the accounts this pipeline IAM role should be created in
  providers = {
    aws = aws.Production
  }

  # Repository name in GitHub
  repository_name = "example-security-inf-repo"

  # Protected branch used by the repo, so that only workflows from that branch allow TF apply actions
  github_branch = "main"

  # Specify the least permissions required for this pipeline to run
  inline_policy = data.aws_iam_policy_document.example_security_inf_repo_Production_permissions.json
}

data "aws_iam_policy_document" "example_security_inf_repo_Production_permissions" {
  statement {
    sid    = "CreateS3buckets"
    effect = "Allow"

    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:PutBucketOwnershipControls",
      "s3:PutEncryptionConfiguration",
      "s3:PutBucketTagging",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketAcl",
      "s3:PutBucketLogging",
      "s3:PutBucketVersioning",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketNotification"
    ]
    # These are buckets that this example application uses to store access logs
    resources = [
      "arn:aws:s3:::centralized-s3-access-logs-us-east-2",
      "arn:aws:s3:::centralized-s3-access-logs-us-east-2/*",
    ]
  }
  statement {
    sid    = "SQSQueues"
    effect = "Allow"

    actions = [
      "sqs:CreateQueue",
      "sqs:DeleteQueue",
      "sqs:TagQueue",
      "sqs:UntagQueue",
      "sqs:SetQueueAttributes"
    ]
    resources = ["arn:aws:sqs:*:${var.account_Production}:aws-s3-access-logs"]

  }
}
