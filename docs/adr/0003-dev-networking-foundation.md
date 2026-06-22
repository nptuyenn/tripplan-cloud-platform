# ADR 0003: Dev Networking Foundation

- Status: Accepted
- Date: 2026-06-22

## Context

The dev environment needs enough AWS networking depth to demonstrate a realistic three-tier platform while keeping cost and operational complexity manageable.

## Decision

The dev VPC uses public, private, and data subnets across two availability zones. Public subnets host internet-facing load balancing and NAT. Private subnets are reserved for Kubernetes nodes. Data subnets are reserved for RDS and Redis and do not receive a default route to the internet.

Dev uses a single NAT Gateway by default to reduce cost. This is less highly available than one NAT Gateway per AZ, but it is acceptable for a short-lived portfolio environment. VPC endpoints are included for S3, ECR, SSM, EC2 messages, SSM messages, and CloudWatch Logs.

## Consequences

- The data tier is isolated from direct internet egress by routing.
- Private Kubernetes nodes can still reach required AWS services through endpoints and can reach external APIs through NAT when needed.
- Single NAT Gateway is a conscious dev cost tradeoff and should be revisited for production.
- VPC Flow Logs are enabled so network behavior can be debugged and demonstrated later.
