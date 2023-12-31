variable "aws_account_id" {
  description = "The AWS account ID where the OIDC provider lives, leave empty to use the account for the AWS provider"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to IAM role resources"
  type        = map(string)
  default     = {}
}

variable "role_name" {
  description = "IAM role name"
  type        = string
  default     = null
}

variable "repository_name" {
  description = "Github Repository name"
  type        = string
  default     = null
}

variable "role_path" {
  description = "Path of IAM role"
  type        = string
  default     = "/"
}

variable "role_permissions_boundary_arn" {
  description = "Permissions boundary ARN to use for IAM role"
  type        = string
  default     = ""
}

variable "max_session_duration" {
  description = "Maximum CLI/API session duration in seconds between 3600 and 43200"
  type        = number
  default     = 3600
}

variable "managed_policies" {
  description = "List of ARNs of IAM policies to attach to main IAM role"
  type        = list(string)
  default     = []
}

variable "force_detach_policies" {
  description = "Whether policies should be detached from this role when destroying"
  type        = bool
  default     = false
}

variable "inline_policy" {
  description = "IAM Inline Policy (String)"
  type        = string
  default     = ""
}

variable "inline_policy_readonly" {
  description = "IAM Inline Policy to attach to the readonly role"
  type        = string
  default     = ""
}

variable "github_environment" {
  description = "Github Environment for this role"
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "Github branch authorized for this role"
  type        = string
  default     = "main"
}

variable "github_organization_name" {
  description = "Name of the GitHub Organization"
  type        = string
}