data "aws_caller_identity" "current" {}

data "aws_organizations_organization" "main" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  branch_name = "main"
}