variable "rvm_role_name" {
  type        = string
  description = "The name of the trusted RVM role in the RVM account"
  default     = "github-workflow-rvm"
}

variable "rvm_account_id" {
  type        = string
  description = "Account ID of the account where RVM is deployed"
}

variable "enable_breakglass_provisioning" {
  type        = bool
  description = "Set to true to attach a policy that allows provisioning roles in the breakglass path."
  default     = false
}