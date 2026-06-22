output "s3_endpoint_id" {
  description = "S3 gateway endpoint ID."
  value       = aws_vpc_endpoint.s3.id
}

output "interface_endpoint_ids" {
  description = "Interface endpoint IDs by service."
  value       = { for service, endpoint in aws_vpc_endpoint.interface : service => endpoint.id }
}

output "interface_endpoint_security_group_id" {
  description = "Security group ID attached to interface endpoints."
  value       = aws_security_group.interface_endpoints.id
}
