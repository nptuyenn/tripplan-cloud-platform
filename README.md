# TripPlan Cloud Platform

TripPlan Cloud Platform is a DevOps and cloud portfolio project for running a travel planning web app on AWS with Terraform, Docker, Kubernetes, GitOps, and observability.

The target application is a React SPA plus a Node.js/Express API backed by Postgres, Redis, and S3 object storage. The infrastructure is built incrementally so each phase can be applied, verified, and destroyed or rolled back.

## Target Architecture

- Frontend: React SPA hosted on S3 and served through CloudFront.
- API: Node.js/Express container deployed to Kubernetes.
- Data: RDS Postgres, ElastiCache Redis, and S3 for trip cover images.
- Networking: AWS VPC with public, private, and data subnets across 2 AZs.
- IaC: Terraform with remote state in S3 and locking through DynamoDB.
- Secrets: AWS Secrets Manager synced into Kubernetes by External Secrets Operator.
- CI/CD: GitHub Actions with AWS OIDC, ECR images tagged by git SHA, and Argo CD GitOps.
- Observability: Prometheus, Grafana, Loki, Tempo/OpenTelemetry, CloudWatch, and VPC Flow Logs.
- Access: SSM Session Manager, with no bastion host and no inbound SSH.

## Repository Layout

```text
tripplan-cloud-platform/
├── frontend/                 # React SPA
├── backend/                  # Express API
├── infra/
│   ├── bootstrap/            # Terraform state bucket, lock table, GitHub OIDC
│   ├── modules/              # Reusable Terraform modules
│   └── envs/                 # Environment roots
├── k8s/                      # Kustomize base and overlays watched by Argo CD
├── argocd/                   # Argo CD Application manifests
├── observability/            # Metrics, logs, traces, dashboards, alerts
├── .github/workflows/        # CI and infrastructure validation workflows
└── docs/adr/                 # Architecture Decision Records
```

## Prerequisites

- Node.js 22 LTS and npm.
- Docker and Docker Compose for local development.
- Terraform CLI for infrastructure code.
- AWS CLI configured by you before running AWS-related commands.
- kubectl for Kubernetes phases.

The project includes `.nvmrc` so local development, CI, and Docker images can stay aligned on Node.js 22.

## Implementation Phases

1. Bootstrap the repo, Terraform remote state, DynamoDB lock table, GitHub OIDC, and first ADR.
2. Build the AWS networking foundation: VPC, subnets, NAT, route tables, endpoints, SSM, and Flow Logs.
3. Build the TripPlan frontend/backend, local Docker Compose stack, API image, ECR repository, probes, metrics, and migrations.
4. Deploy the backend to EKS with External Secrets Operator, AWS Load Balancer Controller, IRSA, and Kubernetes networking controls.
5. Add GitHub Actions CI for backend, frontend, images, security scanning, and Terraform validation.
6. Add Argo CD GitOps, sync hooks, image tag rollout, migration jobs, self-heal, and rollback.
7. Add observability with Prometheus, Grafana, Loki, Tempo/OpenTelemetry, SLOs, and alerts.
8. Polish documentation, cost notes, demos, and portfolio materials.

## Cost Awareness

This project intentionally uses AWS managed services such as EKS, NAT Gateway, RDS, ALB, CloudWatch Logs, and VPC endpoints. Cost is tracked for documentation, but architecture consistency is prioritized over minimizing the bill.

## Bootstrap Notes

AWS connection and credentials are intentionally left to the project owner. The Terraform code in `infra/bootstrap/` prepares the remote state bucket, DynamoDB lock table, GitHub OIDC provider, and GitHub Actions IAM role, but it should only be initialized and applied after you have chosen the AWS account, region, repository name, and globally unique S3 bucket name.

Example flow when you are ready:

```bash
cd infra/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS/GitHub values.
terraform init
terraform plan
terraform apply
```

Do not commit `terraform.tfvars` or any local AWS credentials.

## Dev Networking Notes

The Terraform code in `infra/envs/dev/` builds the Phase 1 networking foundation with:

- one VPC across two availability zones
- public, private, and data subnet tiers
- an internet gateway for public subnets
- NAT Gateway per AZ by default for private subnet egress
- data subnet route tables without a default internet route
- VPC Flow Logs to CloudWatch
- VPC endpoints for S3, ECR, SSM, EC2 messages, SSM messages, and CloudWatch Logs

The dev environment uses the same high-level networking shape expected later: private EKS nodes, managed AWS integration, and NAT placement per AZ by default.

Example flow when you are ready to create dev networking:

```bash
cd infra/envs/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if needed.
terraform init
terraform plan
terraform apply
```

## Current Status

The repository foundation, Phase 0 bootstrap, and Phase 1 dev networking skeleton are initialized. Apply AWS stacks manually only when you are ready for the related AWS costs.
