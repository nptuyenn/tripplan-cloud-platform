variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "environment" {
  description = "Environment name used for resource naming."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability zones used by the VPC."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets. Must align with azs by index."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private EKS node subnets. Must align with azs by index."
  type        = list(string)
}

variable "data_subnet_cidrs" {
  description = "CIDR blocks for data subnets. Must align with azs by index."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether private subnets get outbound internet access through NAT."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway for all private subnets. Set false for one NAT Gateway per AZ."
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "CloudWatch retention in days for VPC Flow Logs."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Additional tags applied to resources."
  type        = map(string)
  default     = {}
}
