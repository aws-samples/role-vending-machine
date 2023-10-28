################################################################################
# github-pipeline-roles module
# This is a helper module used to simplify deployment of GitHub workflow roles via the role vending machine.
################################################################################
locals {
  aws_account_id = var.aws_account_id != "" ? var.aws_account_id : data.aws_caller_identity.current.account_id

  role_name        = coalesce(var.role_name, "github-workflow-role-${var.repository_name}")
  role_description = "Github Workflow Role for ${var.github_organization_name}/${var.repository_name}"

  github_environment = var.github_environment != "" ? "repo:${var.github_organization_name}/${var.repository_name}:environment:${var.github_environment}" : ""

  oidc_subscribers = compact([
    "repo:${var.github_organization_name}/${var.repository_name}:ref:refs/heads/${var.github_branch}",
    local.github_environment
  ])
  # Readonly roles should be consumable by pull requests, or by the main branch (for use in workflow dispatches)
  readonly_oidc_subscribers = concat(local.oidc_subscribers,
    ["repo:${var.github_organization_name}/${var.repository_name}:pull_request"]
  )

  managed_policies          = concat(var.managed_policies, ["arn:aws:iam::aws:policy/ReadOnlyAccess"])
  managed_policies_readonly = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]

}

################################################################################
# Terraform Apply Role / Main Branch
################################################################################

resource "aws_iam_role" "main" {
  name                 = local.role_name
  description          = local.role_description
  path                 = var.role_path
  max_session_duration = var.max_session_duration

  force_detach_policies = var.force_detach_policies
  permissions_boundary  = var.role_permissions_boundary_arn

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${local.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "token.actions.githubusercontent.com:sub" : local.oidc_subscribers
          },
          "StringLike" : {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "custom" {
  count = length(local.managed_policies)

  role       = aws_iam_role.main.name
  policy_arn = local.managed_policies[count.index]
}

resource "aws_iam_role_policy" "workflow_role_state_access" {
  name = "tf-remote-state-access"
  role = aws_iam_role.main.name
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
          "arn:aws:s3:::${local.aws_account_id}-tf-remote-state",
          "arn:aws:s3:::${local.aws_account_id}-tf-remote-state/*",
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
      }
    ]
  })
}

resource "aws_iam_role_policy" "inline_policy" {
  count = var.inline_policy != "" ? 1 : 0

  name   = "inline-policy"
  role   = aws_iam_role.main.name
  policy = var.inline_policy
}

################################################################################
# Terraform Plan Role / Read Only
################################################################################

resource "aws_iam_role" "readonly" {
  name = "${local.role_name}-readonly"
  #name_prefix          = var.role_name_prefix
  description          = local.role_description
  path                 = var.role_path
  max_session_duration = var.max_session_duration

  force_detach_policies = var.force_detach_policies
  permissions_boundary  = var.role_permissions_boundary_arn

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${local.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "token.actions.githubusercontent.com:sub" : local.readonly_oidc_subscribers
          },
          "StringLike" : {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "workflow_role_state_access_readonly" {
  name = "tf-remote-state-access"
  role = aws_iam_role.readonly.name
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
          "arn:aws:s3:::${local.aws_account_id}-tf-remote-state",
          "arn:aws:s3:::${local.aws_account_id}-tf-remote-state/*",
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
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "readonly" {
  count = length(local.managed_policies_readonly)

  role       = aws_iam_role.readonly.name
  policy_arn = local.managed_policies_readonly[count.index]
}

resource "aws_iam_role_policy" "inline_policy_readonly" {
  count = var.inline_policy_readonly != "" ? 1 : 0

  name   = "inline-policy"
  role   = aws_iam_role.readonly.name
  policy = var.inline_policy_readonly
}
