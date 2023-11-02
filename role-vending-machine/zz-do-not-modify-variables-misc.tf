variable "default_github_organization_name" {
  description = "Name of the default GitHub Organization. If not specified otherwise, the role's trust policy will give permissions to the specified repository in this organization."
  type        = string
}