################################################################################
# github-pipeline-roles module
# This is a helper module used to simplify deployment of GitHub workflow roles via the role vending machine.
################################################################################
locals {
  aws_account_id = var.aws_account_id != "" ? var.aws_account_id : data.aws_caller_identity.current.account_id

  role_name        = var.principal_type == "github" ? coalesce(var.role_name, "github-workflow-role-${var.repository_name}") : var.role_name
  role_description = var.principal_type == "github" ? "Github Workflow Role for ${var.github_organization_name}/${var.repository_name}" : "IAM role created by Role Vending Machine"

  github_environment = var.github_environment != "" ? "repo:${var.github_organization_name}/${var.repository_name}:environment:${var.github_environment}" : ""

  oidc_subscribers = var.principal_type == "github" ? compact([
    "repo:${var.github_organization_name}/${var.repository_name}:ref:refs/heads/${var.github_branch}",
    local.github_environment
  ]) : null
  # Readonly roles should be consumable by pull requests, or by the main branch (for use in workflow dispatches)
  readonly_oidc_subscribers = var.principal_type == "github" ? concat(local.oidc_subscribers,
    ["repo:${var.github_organization_name}/${var.repository_name}:pull_request"]
  ) : null

  managed_policies          = concat(var.managed_policies, ["arn:aws:iam::aws:policy/ReadOnlyAccess"])
  managed_policies_readonly = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]

  pod_trust_policy_controls = {
    include_source_account          = true
    include_cluster_arns            = true
    include_cluster_names           = true
    include_cluster_namspaces       = true
    include_cluster_service_account = true
  }

  eks_cluster_arn     = local.pod_trust_policy_controls.include_cluster_arns ? var.eks_cluster_arn : []
  eks_cluster_name    = local.pod_trust_policy_controls.include_cluster_names ? var.eks_cluster_name : []
  eks_namespaces      = local.pod_trust_policy_controls.include_cluster_namspaces ? var.eks_namespaces : []
  eks_service_account = local.pod_trust_policy_controls.include_cluster_service_account ? var.eks_service_account : []

  service_trust_policy_controls = {
    include_account_condition = true
    include_service_arn       = true
  }

  service_arn = local.service_trust_policy_controls.include_service_arn ? var.service_arn : []
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

  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags = var.tags
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = var.principal_type == "pod" ? ["sts:AssumeRole", "sts:TagSession"] : var.principal_type == "service" ? ["sts:AssumeRole"] : ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = var.principal_type == "github" ? "Federated" : "Service"
      identifiers = var.principal_type == "github" ? ["arn:aws:iam::${local.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"] : var.principal_type == "pod" ? ["pods.eks.amazonaws.com"] : var.service_name
    }

    dynamic "condition" {
      for_each = var.principal_type == "github" ? [1] : []
      content {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:aud"
        values   = ["sts.amazonaws.com"]
      }
    }

    dynamic "condition" {
      for_each = var.principal_type == "github" ? [1] : []
      content {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:sub"
        values   = local.oidc_subscribers
      }
    }

    dynamic "condition" {
      for_each = var.principal_type == "pod" && local.pod_trust_policy_controls.include_source_account ? { "source_account" = local.aws_account_id } : {}
      content {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [condition.value]
      }
    }

    dynamic "condition" {
      for_each = var.principal_type == "pod" && length(local.eks_cluster_arn) > 0 ? { "eks-cluster-arn" = local.eks_cluster_arn } : {}
      content {
        test     = "StringEquals"
        variable = "aws:PrincipalTag/eks-cluster-arn"
        values   = condition.value
      }
    }

    dynamic "condition" {
      for_each = var.principal_type == "pod" && length(local.eks_cluster_name) > 0 ? { "eks-cluster-name" = local.eks_cluster_name } : {}
      content {
        test     = "StringEquals"
        variable = "aws:PrincipalTag/eks-cluster-name"
        values   = condition.value
      }
    }

    dynamic "condition" {
      for_each = var.principal_type == "pod" && length(local.eks_namespaces) > 0 ? { "kubernetes-namespace" = local.eks_namespaces } : {}
      content {
        test     = "StringEquals"
        variable = "aws:PrincipalTag/kubernetes-namespace"
        values   = condition.value
      }
    }

    dynamic "condition" {
      for_each = var.principal_type == "pod" && length(local.eks_service_account) > 0 ? { "kubernetes-service-account" = local.eks_service_account } : {}
      content {
        test     = "StringEquals"
        variable = "aws:PrincipalTag/kubernetes-service-account"
        values   = condition.value
      }
    }

    dynamic "condition" {
      for_each = var.principal_type == "service" ? [1] : []
      content {
        test     = "StringEquals"
        variable = "aws:SourceOrgID"
        values   = ["$${aws:ResourceOrgId}"]
      }
    }

    dynamic "condition" {
      for_each = var.principal_type == "service" && local.service_trust_policy_controls.include_account_condition ? { "source_account" = local.aws_account_id } : {}
      content {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [condition.value]
      }
    }

    dynamic "condition" {
      for_each = var.principal_type == "service" && length(local.service_arn) > 0 ? { "service-arns" = local.service_arn } : {}
      content {
        test     = "StringEquals"
        variable = "aws:SourceArn"
        values   = condition.value
      }
    }
  }
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
  count = var.principal_type == "github" ? 1 : 0

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
  count = var.principal_type == "github" ? 1 : 0

  name = "tf-remote-state-access"
  role = aws_iam_role.readonly[0].name
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
  count = var.principal_type == "github" ? length(local.managed_policies_readonly) : 0

  role       = aws_iam_role.readonly[0].name
  policy_arn = local.managed_policies_readonly[count.index]
}

resource "aws_iam_role_policy" "inline_policy_readonly" {
  count = var.principal_type == "github" && var.inline_policy_readonly != "" ? 1 : 0

  name   = "inline-policy"
  role   = aws_iam_role.readonly[0].name
  policy = var.inline_policy_readonly
}
