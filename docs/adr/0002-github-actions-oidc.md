# ADR 0002: GitHub Actions AWS Authentication

- Status: Accepted
- Date: 2026-06-21

## Context

The project needs CI workflows that can validate infrastructure, build images, push to ECR, and deploy frontend assets. Long-lived AWS access keys in GitHub secrets increase rotation work and make accidental exposure more damaging.

## Decision

GitHub Actions will authenticate to AWS through OpenID Connect. The bootstrap Terraform stack creates the GitHub OIDC provider and an IAM role that only the configured repository and branch can assume.

## Consequences

- CI does not need long-lived AWS access keys.
- AWS permissions are controlled through IAM role policies and trust conditions.
- The GitHub repository owner, repository name, and default branch must be configured correctly before applying the bootstrap stack.
- Additional permissions should be added deliberately as later phases introduce ECR, S3 frontend deploys, Terraform environment applies, and Kubernetes deployment workflows.
