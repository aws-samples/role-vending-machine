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

variable "enable_breakglass_provisioning" {
  type        = bool
  description = "Set to true to enable the breakglass provisioning"
  default     = false
}

variable "breakglass_role_name" {
  type        = string
  description = "Name of the role in RVM account that allows the RVM to assume"
  default     = "github-breakglass-rvm"
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

variable "is_proto_rvm" {
  type        = bool
  description = "If you are bootstrapping Proto-RVM (a fork of RVM that does not use OIDC) set this to true."
  default     = false
}

variable "trusted_sso_permission_set" {
  type        = string
  description = "In ProtoRVM, the SSO permission set that is trusted to assume the RVM role in the IAM admin account."
  default     = "" # eg. AWSAdministratorAccess
}
