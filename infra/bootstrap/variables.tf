variable "aws_region" {
  description = "AWS region used for bootstrap resources."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name used for naming and tagging."
  type        = string
  default     = "tripplan"
}

variable "environment" {
  description = "Bootstrap environment name."
  type        = string
  default     = "bootstrap"
}

variable "owner" {
  description = "Owner tag value for cost allocation."
  type        = string
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state."
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking."
  type        = string
  default     = "tripplan-terraform-locks"
}

variable "github_owner" {
  description = "GitHub organization or username that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "github_default_branch" {
  description = "GitHub branch allowed to assume the deploy role."
  type        = string
  default     = "main"
}

variable "github_actions_role_name" {
  description = "IAM role name assumed by GitHub Actions through OIDC."
  type        = string
  default     = "tripplan-github-actions"
}
