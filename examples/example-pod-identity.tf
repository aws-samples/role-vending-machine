module "example-pod-identity_Production" {
  source                   = "../github-workflow-roles"
  github_organization_name = var.default_github_organization_name

  # Providers block is used to indicate the accounts this pipeline IAM role should be created in
  providers = {
    aws = aws.Production
  }

  # Specify the least permissions required for this pipeline to run
  inline_policy = data.aws_iam_policy_document.example-pod-identity_Production_permissions.json

  principal_type = "pod"

  eks_cluster_name = ["my-cluster-1", "my-cluster-2"]

  eks_namespaces = ["namespace-1", "namespace-2"]

  eks_service_account = ["service-account-1", "service-account-2"]

  eks_cluster_arns = ["arn:aws:eks:us-west-2:${var.account_Production}:cluster/my-cluster-1", "arn:aws:eks:us-west-2:${var.account_Production}:cluster/my-cluster-2"]

  role_name = "RVM-pod-identity-role"
}

data "aws_iam_policy_document" "example-pod-identity_Production_permissions" {
  # Specify the permissions that your workflow role needs using this resource
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
    resources = [
      "arn:aws:s3:::centralized-s3-access-logs",
      "arn:aws:s3:::centralized-s3-access-logs/*",
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
    # Instead of hard-coding account numbers, reference the variable names stored in the `variables-accounts` manifest
    resources = ["arn:aws:sqs:*:${var.account_Production}:aws-s3-access-logs"]
  }
}