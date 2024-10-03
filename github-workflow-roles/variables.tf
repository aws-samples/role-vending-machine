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

variable "rvm_assume_role_name" {
  type        = string
  description = "The name of the trusted RVM role in the target accounts"
  default     = "github-assume-role-rvm"
}

variable "repository_name" {
  description = "Github Repository name"
  type        = string
  default     = null
}

variable "role_description" {
  description = "Role description"
  type        = string
  default     = null
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

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "The max_session_duration must be between 3600 and 43200 seconds (1 hour and 12 hours)."
  }
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

variable "principal_type" {
  description = "Type of principal assuming the role (github, service, pod, breakglass)"
  type        = string
  default     = "github"

  validation {
    condition     = contains(["github", "service", "pod", "breakglass"], var.principal_type)
    error_message = "The principal_type must be one of: github, service, pod, or breakglass."
  }
}

# Variables for github principal type
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
  description = "Name of the GitHub Organization - Required if 'principal_type' is 'github'"
  type        = string
  default     = null
}


# Variables for pod principal type
variable "eks_cluster_arns" {
  description = "List of cluster ARNs for pod principal type"
  type        = list(string)
  default     = []
}

variable "eks_cluster_name" {
  description = "List of cluster names for pod principal type"
  type        = list(string)
  default     = []
}

variable "eks_namespaces" {
  description = "List of Kubernetes namespaces for pod principal type"
  type        = list(string)
  default     = []
}

variable "eks_service_account" {
  description = "List of Kubernetes service accounts for pod principal type"
  type        = list(string)
  default     = []
}

variable "pod_trust_policy_controls" {
  description = "specifies conditions for pod identity trust policy"
  type = object({
    include_source_account          = bool
    include_cluster_arns            = bool
    include_cluster_names           = bool
    include_cluster_namspaces       = bool
    include_cluster_service_account = bool
  })
  default = {
    include_cluster_arns            = false
    include_cluster_names           = false
    include_cluster_namspaces       = false
    include_cluster_service_account = false
    include_source_account          = false
  }
}

# Variables for service principal type
variable "service_name" {
  description = "List of services allowed to assume the role"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.service_name) == 0 || can(regex("^[A-Za-z0-9.-]+\\.amazonaws\\.com$", var.service_name))
    error_message = "The service_name variable must be in the format of *.amazonaws.com and can only contain letters, numbers, hyphens, and dots."
  }
}

variable "service_trust_policy_controls" {
  description = "specifies conditions for service role trust policy"
  type = object({
    include_account_condition = bool
    include_org_condition     = bool
  })
  default = {
    include_account_condition = false
    include_org_condition     = false
  }
}

# Variables for break glass principal type
variable "breakglass_user_alias" {
  description = "Name of the break glass user"
  type        = string
  default     = null
}

variable "breakglass_user_email" {
  description = "Email of the break glass user"
  type        = string
  default     = null

  validation {
    condition     = var.breakglass_user_email == null || can(regex("^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$", var.breakglass_user_email))
    error_message = "The breakglass_user_email must be a valid email address or left empty."
  }
}

variable "rvm_account_id" {
  description = "Account ID of the RVM account"
  type        = string
  default     = ""

}