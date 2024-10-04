# This role must be created in each account so that RVM can assume it to locally create roles
module "github_assume_role_rvm" {
  #checkov:skip=CKV_TF_1:cannot provide commit hash for TF repository
  source            = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  role_requires_mfa = false
  version           = "5.30.0"
  create_role       = true
  role_name         = "github-assume-role-rvm"
  trusted_role_arns = [
    "arn:aws:iam::${var.rvm_account_id}:role/${var.rvm_role_name}"
  ]
}
resource "aws_iam_role_policy_attachment" "github_assume_role_rvm_readonly_access" {
  role       = module.github_assume_role_rvm.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
resource "aws_iam_role_policy" "github_assume_role_rvm_management" {
  name = "github-assume-role-rvm-management"
  role = module.github_assume_role_rvm.iam_role_name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "iam:*Role*",
        ],
        "Resource" : [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/RVM/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_assume_role_breakglass_management" {
  count = var.enable_breakglass_provisioning ? 1 : 0
  name  = "github-assume-role-breakglass-management"
  role  = module.github_assume_role_rvm.iam_role_name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "iam:*Role*",
        ],
        "Resource" : [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/breakglass/*"
        ]
      }
    ]
  })
}

# Create a read-only role that can be assumed by read-only RVM workflows
module "github_assume_role_rvm_readonly" {
  #checkov:skip=CKV_TF_1:cannot provide commit hash for TF repository
  source            = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  role_requires_mfa = false
  version           = "5.30.0"
  create_role       = true
  role_name         = "github-assume-role-rvm-readonly"
  trusted_role_arns = [
    "arn:aws:iam::${var.rvm_account_id}:role/${var.rvm_role_name}-readonly",
  ]
}
resource "aws_iam_role_policy_attachment" "github_assume_role_rvm_readonly_ro_access" {
  role       = module.github_assume_role_rvm_readonly.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
