data "aws_caller_identity" "current" {}

data "aws_organizations_organization" "main" {}

data "aws_iam_policy_document" "proto_rvm_sso_trust" {
  statement {
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "ArnLike"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_${var.trusted_sso_permission_set}_*"]
      variable = "aws:PrincipalArn"
    }
  }
}
