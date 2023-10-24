### IAM Role with OIDC trust for Read-only operations during planning ###
module "workflow_role_readonly" {
  source                         = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                        = "5.30.0"
  create_role                    = true
  role_name                      = "${var.iam_role_name}-readonly"
  provider_url                   = "https://token.actions.githubusercontent.com"
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]
  oidc_fully_qualified_subjects  = ["repo:${var.github_organization}/${var.github_repo}:pull_request"]
}
resource "aws_iam_role_policy_attachment" "workflow_role_readonly_state_access" {
  role       = module.workflow_role_readonly.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
resource "aws_iam_role_policy" "workflow_role_readonly_state_access" {
  name = "tf-remote-state-access"
  role = module.workflow_role_readonly.iam_role_name
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
          "arn:aws:dynamodb:${local.account_id}:*:table/tf-state-lock"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy" "workflow_role_management_readonly" {
  name = "github-workflow-role-management-readonly"
  role = module.workflow_role_readonly.iam_role_name
  policy = jsonencode({
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
          "arn:aws:iam::*:role/github-assume-role-rvm"
        ]
      }
    ]
  })
}

### IAM Role with OIDC trust for creating resources ###
module "workflow_role" {
  source                         = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                        = "5.30.0"
  create_role                    = true
  role_name                      = var.iam_role_name
  provider_url                   = "https://token.actions.githubusercontent.com"
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]
  oidc_fully_qualified_subjects = [
    "repo:${var.github_organization}/${var.github_repo}:ref:refs/heads/main",
    # "repo:${var.github_organization}/${var.github_repo}:environment:${var.github_environment}" # Optional: GitHub environments can also be used to delegate trust, beyond just branch names
  ]
}
resource "aws_iam_role_policy_attachment" "workflow_role_state_access" {
  role       = module.workflow_role.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
resource "aws_iam_role_policy" "workflow_role_state_access" {
  name = "tf-remote-state-access"
  role = module.workflow_role.iam_role_name
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
          "arn:aws:dynamodb:${local.account_id}:*:table/tf-state-lock"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy" "workflow_role_management" {
  name = "github-workflow-role-management"
  role = module.workflow_role.iam_role_name
  policy = jsonencode({
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
          "arn:aws:iam::*:role/github-assume-role-rvm"
        ]
      }
    ]
  })
}
### IAM Role with Assume Role access for creating Consumer roles ###
module "github_assume_role_rvm" {
  source         = "../assumed_role"
  rvm_account_id = local.account_id
  rvm_role_name  = module.workflow_role.iam_role_name
}
