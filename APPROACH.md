# APPROACH.md — Architecture Rationale & Decision Log

## Overview

This document explains *why* each major decision was made, not just what was built.
The goal was a setup that a real startup (8byte) could actually use in production
without significant rework.

---

## Part 1: Infrastructure (Terraform)

### Why Terraform over CloudFormation or CDK?

Terraform is cloud-agnostic, has a massive module ecosystem, and its HCL syntax
is significantly more readable than JSON/YAML CloudFormation. For a startup that
may want to run workloads on multiple clouds in the future, Terraform avoids
vendor lock-in at the IaC layer.

### Why ECS Fargate over raw EC2 or EKS?

| Option | Pro | Con |
|--------|-----|-----|
| **EC2** | Full control | Must patch OS, manage capacity |
| **ECS Fargate** | No servers to manage, per-second billing | Less control, AWS-specific |
| **EKS** | Industry standard, very extensible | Overkill for a startup; ~$70/mo just for control plane |

**Decision:** ECS Fargate gives 80% of Kubernetes's benefits (container orchestration,
rolling deploys, health checks, service discovery) at 20% of the operational overhead.
For a startup with a small team, this is the right trade-off.

### Why three-tier security group model?

```
Internet → ALB SG → App SG → RDS SG
```

Each security group only allows ingress from the tier directly above it. The RDS
instance literally cannot be reached from the internet — even if an attacker
compromised the ALB, they still cannot reach the database without also compromising
an app container. This is defense-in-depth at the network layer.

### Why Remote State (S3 + DynamoDB)?

Local `terraform.tfstate` is dangerous on a team: two engineers running `apply`
simultaneously can corrupt state. The S3 backend stores state remotely and
DynamoDB provides a pessimistic lock. This is the standard production pattern.

### Module Structure Rationale

Each AWS service gets its own module (`vpc`, `alb`, `ecs`, `rds`, `security_groups`).
This means:
- Each module can be tested independently.
- Staging and production use the same modules but different `tfvars`.
- No copy-pasting of resource blocks between environments.

---

## Part 2: CI/CD (GitHub Actions)

### Why GitHub Actions over Jenkins?

- Zero infrastructure to maintain (Jenkins needs its own server).
- Native GitHub integration: PR comments, branch protection, environment gates.
- Free for public repos; very affordable for private.
- YAML workflows are version-controlled alongside the code.

### Pipeline Job Separation Strategy

Tests, security scanning, image building, and deployment are separate jobs (not steps
in one job). This matters because:
- Failed tests stop the pipeline immediately, saving ECR storage.
- Security scanning runs *in parallel* with other steps where possible.
- Each job has its own GitHub environment, enabling different secrets and approval gates.

### Why Trivy for both filesystem and image scanning?

Trivy is the industry standard (used by GitHub, DockerHub internally, etc.), is fast,
and covers both dependency vulnerabilities (npm audit equivalent) and OS-layer CVEs
in the final Docker image. Running it at both stages catches:
1. **Filesystem scan**: vulnerable npm packages before the image is even built.
2. **Image scan**: vulnerable OS packages (e.g., Alpine CVEs) in the final image.

### Manual Approval Gate Implementation

GitHub Actions supports "environments" that can require reviewers. The `production`
environment is configured to require at least one reviewer before the deploy job runs.
This creates an auditable paper trail: who approved, at what time, for which commit.

---

## Part 3: Monitoring & Logging

### Why Prometheus + Grafana over CloudWatch-only?

CloudWatch is convenient but expensive at scale and its dashboarding is limited.
Prometheus + Grafana gives:
- Rich, flexible dashboards with Grafana.
- alerting rules as code (version-controlled `alert_rules.yml`).
- The same stack works locally (Docker Compose) and in production.
- Open-source with zero per-metric cost.

CloudWatch is still used for log aggregation (application logs from ECS containers)
because it's the native AWS logging sink for Fargate and requires zero additional
infrastructure.

### Three Observability Signals

The monitoring setup covers the three pillars:

1. **Metrics** — Prometheus scrapes app, host (node-exporter), DB (postgres-exporter), and container (cAdvisor) metrics.
2. **Logs** — CloudWatch Logs aggregates ECS container output. ALB access logs go to S3.
3. **Alerts** — Prometheus alert rules fire to Alertmanager, which sends Slack notifications.

### Dashboard Design

Two dashboards were created:
- **Infrastructure** focuses on host/container resources (CPU, memory, disk, network).
- **Application** focuses on the four golden signals: latency, traffic, errors, and saturation (DB connections).

This matches how an on-call engineer thinks: "Is it infrastructure or application?"

---

## Part 4: Security & Secrets

### Why AWS Secrets Manager over Parameter Store?

Secrets Manager provides automatic secret rotation (can rotate RDS passwords
automatically), whereas Parameter Store does not. For database credentials, automatic
rotation is a significant security advantage. The cost difference (~$0.40/secret/month)
is negligible.

### Secret Injection Pattern

```
Secrets Manager  ←  IAM role grants ECS task execution role read access
       ↓
ECS task definition references secret ARN  →  injected as env var at task startup
       ↓
Application reads DB_SECRET env var (JSON)  →  parses host, port, username, password
```

Secrets never appear in code, Dockerfiles, CloudWatch logs, or Git history.

### Backup Strategy

- **RDS**: Automated backups enabled with 7-day retention window (`03:00–04:00 UTC`).
  Point-in-time recovery is available for any moment in the last 7 days.
- **Terraform state**: S3 versioning enabled on the state bucket — previous state
  versions are retained and can be restored if state is accidentally corrupted.

---

## What I Would Add Given More Time

1. **HTTPS / ACM certificate**: Add an ACM certificate to the ALB HTTPS listener.
2. **WAF**: AWS WAF in front of the ALB to block common attack patterns.
3. **ECS Exec**: Enable ECS Exec for secure, SSH-less container debugging.
4. **Auto-scaling**: ECS Application Auto Scaling based on ALB request count.
5. **Fargate Spot**: Add a Spot capacity provider to cut compute costs ~70%.
6. **Centralized logging with OpenSearch**: Ship CloudWatch logs to OpenSearch
   for full-text search and log analytics beyond what CloudWatch Insights offers.
7. **Terraform workspaces or Terragrunt**: Manage multiple environment states
   without duplicating `tfvars` files.
