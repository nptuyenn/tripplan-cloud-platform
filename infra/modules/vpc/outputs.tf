output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "azs" {
  description = "Availability zones used by this VPC."
  value       = var.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = values(aws_subnet.public)[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for EKS worker nodes."
  value       = values(aws_subnet.private)[*].id
}

output "data_subnet_ids" {
  description = "Data subnet IDs for RDS and Redis."
  value       = values(aws_subnet.data)[*].id
}

output "public_route_table_id" {
  description = "Public route table ID."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private route table IDs."
  value       = values(aws_route_table.private)[*].id
}

output "data_route_table_ids" {
  description = "Data route table IDs."
  value       = values(aws_route_table.data)[*].id
}

output "flow_log_group_name" {
  description = "CloudWatch log group name for VPC Flow Logs."
  value       = aws_cloudwatch_log_group.flow_logs.name
}
