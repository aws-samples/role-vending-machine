data "aws_caller_identity" "current" {}
# This role must be created in each account so that RVM can assume it to locally create roles
module "github_assume_role_rvm" {
  source            = "terraform-aws-modules/iam/aws//modules/iam-assumable-role?ref=8af6d28"
  role_requires_mfa = false
  version           = "5.28.0"
  create_role       = true
  role_name         = "github-assume-role-rvm"
  trusted_role_arns = [
    "arn:aws:iam::${var.rvm_account_id}:role/${var.rvm_role_name}-readonly",
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
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/github-workflow-role-*"
        ]
      }
    ]
  })
}