# IAM OpenID connect provider for GitHub
resource "aws_iam_openid_connect_provider" "github" {
  client_id_list = concat(
    ["https://github.com/${var.github_organization}"],
    ["sts.amazonaws.com"]
  )
  thumbprint_list = var.github_thumbprint_list
  url             = "https://token.actions.githubusercontent.com"
}