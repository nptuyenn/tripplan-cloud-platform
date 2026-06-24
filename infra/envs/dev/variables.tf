variable "aws_region" {
  description = "AWS region for the dev environment."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name used for naming and tagging."
  type        = string
  default     = "tripplan"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag value for cost allocation."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the dev VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones used by the dev VPC."
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private EKS node subnets."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "data_subnet_cidrs" {
  description = "CIDR blocks for data subnets."
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether private subnets get outbound internet access through NAT."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway for all private subnets. Dev defaults to one NAT Gateway per AZ for consistency."
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "CloudWatch retention in days for VPC Flow Logs."
  type        = number
  default     = 14
}
