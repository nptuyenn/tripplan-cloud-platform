# ADR 0001: Initial Architecture Decisions

- Status: Accepted
- Date: 2026-06-21

## Context

TripPlan Cloud Platform is a portfolio project intended to demonstrate practical AWS networking, Terraform, CI/CD, Kubernetes, GitOps, and observability skills. The project should be realistic enough for production-style discussion while remaining small enough to build, verify, and destroy safely.

## Decisions

1. The frontend is a static React SPA deployed to S3 and served through CloudFront. Express is responsible only for API routes under `/api/...`.
2. Terraform state is stored remotely in S3 with DynamoDB state locking. Local state is not used for shared environments.
3. Runtime secrets are stored in AWS Secrets Manager and synced into Kubernetes through External Secrets Operator.
4. GitHub Actions authenticates to AWS through OIDC. Long-lived AWS access keys are not used in CI.
5. Container images are tagged with the git SHA. The `latest` tag is not used for deployable releases.
6. Kubernetes manifests use Kustomize with `base/`, `overlays/dev`, and `overlays/prod`. Helm is reserved for third-party platform components.
7. Node access uses SSM Session Manager. Bastion hosts and inbound SSH are avoided.

## Consequences

- Frontend and API delivery paths are independently scalable and cacheable.
- Terraform operations are safer because state is centralized and locked.
- Secret handling is auditable and avoids committing credentials to Git.
- CI access to AWS can be scoped and rotated by trust policy instead of static keys.
- GitOps rollbacks are easier because image versions are immutable.
- The same Kubernetes base can be reused across k3s and EKS with environment-specific overlays.
- Operational access is more secure, but SSM endpoints and IAM permissions must be included in the infrastructure.
