output "iam_role_arn" {
  description = "ARN of IAM role"
  value       = try(aws_iam_role.main.arn, "")
}

output "iam_role_name" {
  description = "Name of IAM role"
  value       = try(aws_iam_role.main.name, "")
}

output "iam_role_path" {
  description = "Path of IAM role"
  value       = try(aws_iam_role.main.path, "")
}

output "iam_role_unique_id" {
  description = "Unique ID of IAM role"
  value       = try(aws_iam_role.main.unique_id, "")
}

output "readonly_iam_role_arn" {
  description = "ARN of read-only IAM role"
  value       = try(aws_iam_role.readonly[0].arn, "")
}

output "readonly_iam_role_name" {
  description = "Name of read-only IAM role"
  value       = try(aws_iam_role.readonly[0].name, "")
}

output "readonly_iam_role_path" {
  description = "Path of read-only IAM role"
  value       = try(aws_iam_role.readonly[0].path, "")
}

output "readonly_iam_role_unique_id" {
  description = "Unique ID of read-only IAM role"
  value       = try(aws_iam_role.readonly[0].unique_id, "")
}