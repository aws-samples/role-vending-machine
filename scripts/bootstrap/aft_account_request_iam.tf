### IAM Role with OIDC trust for Read-only operations during planning ###
module "workflow_role_readonly_aft_account_request" {
  # checkov:skip=CKV_TF_1:Terraform registry modules cannot be referenced via commit hash
  source                         = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                        = "4.7.0"
  create_role                    = true
  role_name                      = "${var.aft_account_request_iam_role_name}-readonly"
  provider_url                   = "https://token.actions.githubusercontent.com"
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]
  oidc_fully_qualified_subjects  = ["repo:${var.github_organization}/${var.aft_account_request_github_repo}:pull_request"]
}
resource "aws_iam_role_policy_attachment" "workflow_role_readonly_state_access_aft_account_request" {
  role       = module.workflow_role_readonly_aft_account_request.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
resource "aws_iam_role_policy" "workflow_role_readonly_state_access_aft_account_request" {
  name = "tf-remote-state-access"
  role = module.workflow_role_readonly_aft_account_request.iam_role_name
  policy = jsonencode({
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
          "arn:aws:s3:::${local.account_id}-tf-remote-state",
          "arn:aws:s3:::${local.account_id}-tf-remote-state/*",
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
          "arn:aws:dynamodb:*:*:table/tf-state-lock"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource" : [
          "arn:aws:kms:us-east-2:${local.account_id}:key/*"
        ]
      }
    ]
  })
}


### IAM Role with OIDC trust for creating resources ###
module "workflow_role_aft_account_request" {
  # checkov:skip=CKV_TF_1:Terraform registry modules cannot be referenced via commit hash
  source                         = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                        = "4.7.0"
  create_role                    = true
  role_name                      = var.aft_account_request_iam_role_name
  provider_url                   = "https://token.actions.githubusercontent.com"
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]
  oidc_fully_qualified_subjects = [
    "repo:${var.github_organization}/${var.aft_account_request_github_repo}:ref:refs/heads/main",
    # "repo:${var.github_organization}/${var.aft_account_request_github_repo}:environment:${var.github_environment}"
  ]
}
resource "aws_iam_role_policy_attachment" "workflow_role_state_access_aft_account_request" {
  role       = module.workflow_role_aft_account_request.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
resource "aws_iam_role_policy" "workflow_role_state_access_aft_account_request" {
  name = "tf-remote-state-access"
  role = module.workflow_role_aft_account_request.iam_role_name
  policy = jsonencode({
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
          "arn:aws:s3:::${local.account_id}-tf-remote-state",
          "arn:aws:s3:::${local.account_id}-tf-remote-state/*",
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
          "arn:aws:dynamodb:*:*:table/tf-state-lock"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource" : [
          "arn:aws:kms:us-east-2:${local.account_id}:key/*"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy" "aft_account_request" {
  name = "aft_account_request"
  role = module.workflow_role_aft_account_request.iam_role_name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:BatchWriteItem",
          "dynamodb:DeleteItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        "Resource" : [
          "arn:aws:dynamodb:us-east-2:${local.account_id}:table/aft-request"
        ]
      }
    ]
  })
}