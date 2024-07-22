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

variable "role_description" {
  description = "Role description"
  type = string
  default = null
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

variable "principal_type" {
  description = "Type of principal assuming the role (github, service, pod)"
  type        = string
  default     = "github"
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
    condition     = can(regex("^[A-Za-z0-9.-]+\\.amazonaws\\.com$", var.service_name))
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