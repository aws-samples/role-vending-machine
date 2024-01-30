variable "github_organization" {
  type        = string
  description = "GitHub Organization name to create OIDC provider for"
}

variable "aws_region" {
  type        = string
  description = "Name of the primary AWS region that this solution will be deployed in"
}

variable "github_repo" {
  type        = string
  description = "GitHub Repo to create OIDC provider for"
  default     = "role-vending-machine"
}

variable "iam_role_name" {
  type        = string
  description = "Name of the role in the RVM account used to assume member account roles"
  default     = "github-workflow-rvm"
}

variable "iam_assuming_role_name" {
  type        = string
  description = "Name of the IAM Role in each member account that RVM's main role can assume."
  default     = "github-assume-role-rvm"
}

variable "create_tf_state_management_infrastructure" {
  type        = bool
  description = "Set to true if you want the bootstrap script to generate Terraform backend infrastructure for the main role-vending-machine module. You might choose to omit this if you create backend infrastructure through some other means, like AFT."
  default     = false
}

variable "ddb_lock_table_name" {
  type        = string
  description = "Name of the Dynamo DB lock table used by RVM's bootstrap"
  default     = "tf-state-lock"
}

variable "bucket_suffix" {
  type        = string
  description = "The suffix (after the account ID) that identifies the Terraform S3 state bucket."
  default     = "tf-remote-state"
}
