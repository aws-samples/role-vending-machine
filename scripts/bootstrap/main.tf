module "state_management" {
  count  = var.create_tf_state_management_infrastructure == true ? 1 : 0
  source = "./state_management"
}

### IAM Role with OIDC trust for Read-only operations during planning ###
# The read-only and non-read-only roles have identical permissions policies, but...
# ...the read-only role is only able to assume read-only roles in member accounts
module "workflow_role_readonly" {
  #checkov:skip=CKV_TF_1:cannot provide commit hash for TF repository
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
  name   = "tf-remote-state-access"
  role   = module.workflow_role_readonly.iam_role_name
  policy = local.terraform_state_policy
}
resource "aws_iam_role_policy" "workflow_role_management_readonly" {
  name   = "github-workflow-role-management-readonly"
  role   = module.workflow_role_readonly.iam_role_name
  policy = local.rvm_readonly_assumption_policy
}

### IAM Role with OIDC trust for creating resources ###
module "workflow_role" {
  #checkov:skip=CKV_TF_1:cannot provide commit hash for TF repository
  source                         = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                        = "5.30.0"
  create_role                    = true
  role_name                      = var.iam_role_name
  provider_url                   = "https://token.actions.githubusercontent.com"
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]
  oidc_fully_qualified_subjects = [
    "repo:${var.github_organization}/${var.github_repo}:ref:refs/heads/${local.protected_branch_name}",
    # Optional: GitHub environments can also be used to delegate trust, beyond just branch names
    # "repo:${var.github_organization}/${var.github_repo}:environment:${var.github_environment}"
  ]
}
resource "aws_iam_role_policy_attachment" "workflow_role_state_access" {
  role       = module.workflow_role.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
resource "aws_iam_role_policy" "workflow_role_state_access" {
  name   = "tf-remote-state-access"
  role   = module.workflow_role.iam_role_name
  policy = local.terraform_state_policy
}
resource "aws_iam_role_policy" "workflow_role_management" {
  name   = "github-workflow-role-management"
  role   = module.workflow_role.iam_role_name
  policy = local.rvm_assumption_policy
}

### IAM Role with OIDC trust for creating break glass role ###
module "breakglass_role" {
  #checkov:skip=CKV_TF_1:cannot provide commit hash for TF repository
  #checkov:skip=CKV_AWS_355:need ability to analyze all IAM policies
  count                          = var.enable_breakglass_provisioning ? 1 : 0
  source                         = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                        = "5.30.0"
  create_role                    = true
  role_name                      = var.breakglass_role_name
  provider_url                   = "https://token.actions.githubusercontent.com"
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]
  oidc_fully_qualified_subjects = [
    "repo:${var.github_organization}/${var.github_repo}:ref:refs/heads/${local.protected_branch_name}",
    # Optional: GitHub environments can also be used to delegate trust, beyond just branch names
    # "repo:${var.github_organization}/${var.github_repo}:environment:${var.github_environment}"
  ]
}

resource "aws_iam_role_policy" "breakglass_role_assumption" {
  count  = var.enable_breakglass_provisioning ? 1 : 0
  name   = "github-breakglass-role-access"
  role   = module.breakglass_role[0].iam_role_name
  policy = local.rvm_breakglass_assumption_policy
}
resource "aws_iam_role_policy" "breakglass_ses_access" {
  count  = var.enable_breakglass_provisioning ? 1 : 0
  name   = "ses-send-email"
  role   = module.breakglass_role[0].iam_role_name
  policy = local.rvm_breakglass_ses_policy
}

resource "aws_iam_role_policy" "breakglass_role_analyzer" {
  #checkov:skip=CKV_AWS_355:need ability to analyze all IAM policies
  count  = var.enable_breakglass_provisioning ? 1 : 0
  name   = "github-breakglass-role-analyzer-access"
  role   = module.breakglass_role[0].iam_role_name
  policy = local.rvm_breakglass_analyzer_policy
}

module "breakglass_role_readonly" {
  #checkov:skip=CKV_TF_1:cannot provide commit hash for TF repository
  #checkov:skip=CKV_AWS_355:need ability to analyze all IAM policies
  count                          = var.enable_breakglass_provisioning ? 1 : 0
  source                         = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                        = "5.30.0"
  create_role                    = true
  role_name                      = "${var.breakglass_role_name}-readonly"
  provider_url                   = "https://token.actions.githubusercontent.com"
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]
  oidc_fully_qualified_subjects = [
    "repo:${var.github_organization}/${var.github_repo}:pull_request",
    # Optional: GitHub environments can also be used to delegate trust, beyond just branch names
    # "repo:${var.github_organization}/${var.github_repo}:environment:${var.github_environment}"
  ]
}

resource "aws_iam_role_policy" "breakglass_role_readonly_analyzer" {
  #checkov:skip=CKV_AWS_355:need ability to analyze all IAM policies
  count  = var.enable_breakglass_provisioning ? 1 : 0
  name   = "github-breakglass-role-analyzer-access"
  role   = module.breakglass_role_readonly[0].iam_role_name
  policy = local.rvm_breakglass_analyzer_policy
}
