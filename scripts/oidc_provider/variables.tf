variable "github_organization" {
  type        = string
  description = "List of GitHub Organizations to create OIDC provider for"
}

variable "github_thumbprint_list" {
  type = list(string)
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "f879abce0008e4eb126e0097e46620f5aaae26ad",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
  description = "The thumbprints to allow based on the instructions here: https://github.blog/changelog/2022-01-13-github-actions-update-on-oidc-based-deployments-to-aws/"
}