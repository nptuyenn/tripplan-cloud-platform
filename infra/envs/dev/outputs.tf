output "vpc_id" {
  description = "Dev VPC ID."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs for EKS worker nodes."
  value       = module.vpc.private_subnet_ids
}

output "data_subnet_ids" {
  description = "Data subnet IDs for RDS and Redis."
  value       = module.vpc.data_subnet_ids
}

output "private_route_table_ids" {
  description = "Private route table IDs."
  value       = module.vpc.private_route_table_ids
}

output "data_route_table_ids" {
  description = "Data route table IDs."
  value       = module.vpc.data_route_table_ids
}

output "flow_log_group_name" {
  description = "CloudWatch log group for VPC Flow Logs."
  value       = module.vpc.flow_log_group_name
}

output "vpc_endpoint_ids" {
  description = "VPC endpoint IDs."
  value = merge(
    { s3 = module.vpc_endpoints.s3_endpoint_id },
    module.vpc_endpoints.interface_endpoint_ids
  )
}
