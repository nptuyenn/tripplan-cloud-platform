variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "environment" {
  description = "Environment name used for resource naming."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block allowed to reach interface endpoints."
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnet IDs for interface endpoints."
  type        = list(string)
}

variable "route_table_ids" {
  description = "Route table IDs that should use the S3 gateway endpoint."
  type        = list(string)
}

variable "tags" {
  description = "Additional tags applied to resources."
  type        = map(string)
  default     = {}
}
