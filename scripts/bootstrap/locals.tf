locals {
  account_id            = data.aws_caller_identity.current.account_id
  protected_branch_name = "main"
  rvm_assumption_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "sts:TagSession",
          "sts:SetSourceIdentity",
          "sts:AssumeRole"
        ],
        "Resource" : [
          "arn:aws:iam::*:role/${var.iam_assuming_role_name}"
        ]
      }
    ]
  })
  rvm_readonly_assumption_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "sts:TagSession",
          "sts:SetSourceIdentity",
          "sts:AssumeRole"
        ],
        "Resource" : [
          "arn:aws:iam::*:role/${var.iam_assuming_role_name}-readonly"
        ]
      }
    ]
  })
  terraform_state_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ],
        "Resource" : [
          "arn:aws:s3:::${local.account_id}-${var.bucket_suffix}",
          "arn:aws:s3:::${local.account_id}-${var.bucket_suffix}/*",
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        "Resource" : [
          "arn:aws:dynamodb:*:${local.account_id}:table/${var.ddb_lock_table_name}"
        ]
      }
    ]
  })
}
