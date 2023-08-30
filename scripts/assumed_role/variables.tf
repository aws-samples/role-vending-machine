variable "rvm_role_name" {
  type        = string
  description = "The name of the trusted RVM role in the RVM account"
  default     = "github-workflow-rvm"
}

variable "rvm_account_id" {
  type        = string
  description = "Account ID of the account where RVM is deployed"
}