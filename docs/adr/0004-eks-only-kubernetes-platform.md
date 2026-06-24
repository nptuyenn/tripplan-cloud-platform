# ADR 0004: EKS-Only Kubernetes Platform

- Status: Accepted
- Date: 2026-06-24

## Context

The original roadmap considered a lightweight self-managed Kubernetes path for dev and EKS for a later migration/demo phase. The project now prioritizes service consistency over minimizing cost, so maintaining two Kubernetes execution models would add unnecessary architectural drift.

## Decision

TripPlan Cloud Platform will use Amazon EKS as the only Kubernetes platform. The project will not build or maintain a separate self-managed Kubernetes-on-EC2 path.

## Consequences

- Kubernetes networking, ingress, IAM, and autoscaling work can be designed around EKS from the beginning.
- The project can use AWS Load Balancer Controller, IRSA, EKS managed node groups, and VPC CNI consistently.
- The roadmap is simpler because there is no migration phase between Kubernetes platforms.
- EKS cost is accepted as part of the platform scope.
