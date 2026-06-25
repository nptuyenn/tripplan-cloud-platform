# ADR 0003: Dev Networking Foundation

- Status: Accepted
- Date: 2026-06-22

## Context

The dev environment needs enough AWS networking depth to demonstrate a realistic three-tier platform while keeping cost and operational complexity manageable.

## Decision

The dev VPC uses public, private, and data subnets across two availability zones. Public subnets host internet-facing load balancing and NAT. Private subnets are reserved for EKS worker nodes. Data subnets are reserved for RDS Postgres and do not receive a default route to the internet.

Dev uses NAT Gateway placement per AZ by default to keep the networking model closer to a production-style AWS setup. VPC endpoints are included for S3, ECR, SSM, EC2 messages, SSM messages, and CloudWatch Logs.

## Consequences

- The data tier is isolated from direct internet egress by routing.
- Private EKS nodes can still reach required AWS services through endpoints and can reach external APIs through NAT when needed.
- Cost is accepted as a tradeoff for a cleaner and more consistent AWS-managed architecture.
- VPC Flow Logs are enabled so network behavior can be debugged and demonstrated later.
