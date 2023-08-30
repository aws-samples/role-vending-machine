# variable "github_environment" {
#   type        = string
#   description = "Provide the Github Repo Environment: dev-control-tower or prod-control-tower"
#   default     = "dev-control-tower"
# }

variable "github_organization" {
  type        = string
  description = "GitHub Organization name to create OIDC provider for"
}

variable "github_repo" {
  type        = string
  description = "GitHub Repo to create OIDC provider for"
  default     = "role-vending-machine"
}

variable "iam_role_name" {
  type        = string
  description = "IAM Role naming pattern"
  default     = "github-workflow-rvm"
}
