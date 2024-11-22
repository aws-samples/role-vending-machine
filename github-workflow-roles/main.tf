################################################################################
# github-pipeline-roles module
# This is a helper module used to simplify deployment of GitHub workflow roles via the role vending machine.
################################################################################
locals {
  aws_account_id = var.aws_account_id != "" ? var.aws_account_id : data.aws_caller_identity.current.account_id
  rvm_account_id = var.rvm_account_id != "" ? var.rvm_account_id : null

  github_organization_name = contains(["github", "breakglass", "sso"], var.principal_type) ? var.vcs_organization_name : null

  role_name        = contains(["sso", "github"], var.principal_type) ? coalesce(var.role_name, "${var.repository_name}-repo-role") : var.role_name
  role_description = contains(["sso", "github"], var.principal_type) ? "Workflow Role for ${local.github_organization_name}/${var.repository_name}" : coalesce(var.role_description, "IAM role created for by Role Vending Machine")

  github_environment = var.github_environment != "" ? "repo:${local.github_organization_name}/${var.repository_name}:environment:${var.github_environment}" : ""

  oidc_subscribers = var.principal_type == "github" ? compact([
    "repo:${local.github_organization_name}/${var.repository_name}:ref:refs/heads/${var.github_branch}",
    local.github_environment
  ]) : null
  # Readonly roles should be consumable by pull requests, or by the main branch (for use in workflow dispatches)
  readonly_oidc_subscribers = var.principal_type == "github" ? concat(local.oidc_subscribers,
    ["repo:${local.github_organization_name}/${var.repository_name}:pull_request"]
  ) : null


  managed_policies          = var.principal_type == "github" ? concat(var.managed_policies, ["arn:aws:iam::aws:policy/ReadOnlyAccess"]) : var.managed_policies
  managed_policies_readonly = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]

  pod_trust_policy_controls = {
    include_source_account          = true
    include_cluster_arns            = true
    include_cluster_names           = true
    include_cluster_namspaces       = true
    include_cluster_service_account = true
  }

  eks_cluster_arns    = local.pod_trust_policy_controls.include_cluster_arns ? var.eks_cluster_arns : []
  eks_cluster_name    = local.pod_trust_policy_controls.include_cluster_names ? var.eks_cluster_name : []
  eks_namespaces      = local.pod_trust_policy_controls.include_cluster_namspaces ? var.eks_namespaces : []
  eks_service_account = local.pod_trust_policy_controls.include_cluster_service_account ? var.eks_service_account : []

  service_trust_policy_controls = {
    include_account_condition = true
    include_org_condition     = true
  }

  sso_arns = var.principal_type == "sso" ? [for permission_set_name in var.trusted_sso_permission_sets : "arn:aws:iam::${local.aws_account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_${permission_set_name}_*"] : []

  path = var.principal_type == "breakglass" ? "/breakglass/" : "/RVM/"
  tags = {
    repository     = contains(["github", "sso"], var.principal_type) ? var.repository_name : null
    principal_type = var.principal_type
    role_arn       = "arn:aws:iam::${local.aws_account_id}:role${local.path}${local.role_name}"
    create_date    = timestamp()
    requester      = var.principal_type == "breakglass" ? var.breakglass_user_alias : null
    email          = var.principal_type == "breakglass" ? var.breakglass_user_email : null
  }
}


################################################################################
# Terraform Apply Role / Main Branch
################################################################################

resource "aws_iam_role" "main" {
  name                 = local.role_name
  description          = local.role_description
  path                 = local.path
  max_session_duration = var.max_session_duration

  force_detach_policies = var.force_detach_policies
  permissions_boundary  = var.role_permissions_boundary_arn

  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags = merge(var.tags, local.tags)

  lifecycle {
    ignore_changes = [tags["create_date"]]
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = var.principal_type == "pod" ? ["sts:AssumeRole", "sts:TagSession"] : var.principal_type == "service" || contains(["breakglass", "sso"], var.principal_type) ? ["sts:AssumeRole"] : ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = var.principal_type == "github" ? "Federated" : contains(["breakglass", "sso"], var.principal_type) ? "AWS" : "Service"

      identifiers = var.principal_type == "github" ? ["arn:aws:iam::${local.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"] : var.principal_type == "pod" ? ["pods.eks.amazonaws.com"] : var.principal_type == "breakglass" ? ["arn:aws:iam::${local.rvm_account_id}:role/github-breakglass-rvm"] : var.principal_type == "sso" ? ["*"] : var.service_name
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
      for_each = var.principal_type == "pod" && length(local.eks_cluster_arns) > 0 ? { "eks-cluster-arn" = local.eks_cluster_arns } : {}
      content {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
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
      for_each = var.principal_type == "service" && local.service_trust_policy_controls.include_org_condition ? [1] : []
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
      for_each = var.principal_type == "sso" && length(local.sso_arns) > 0 ? [1] : []
      content {
        test     = "ArnLike"
        variable = "aws:PrincipalArn"
        values   = local.sso_arns
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
  count = var.principal_type == "github" ? 1 : 0
  name  = "tf-remote-state-access"
  role  = aws_iam_role.main.name
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
  path                 = "/RVM/"
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
