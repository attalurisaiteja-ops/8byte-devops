# 8byte DevOps Assignment

A production-grade DevOps setup featuring Infrastructure as Code (Terraform on AWS), automated CI/CD (GitHub Actions), container orchestration (ECS Fargate), managed PostgreSQL (RDS), and full observability stack (Prometheus + Grafana).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start (Local Development)](#quick-start-local-development)
4. [Infrastructure Setup (AWS)](#infrastructure-setup-aws)
5. [CI/CD Pipeline](#cicd-pipeline)
6. [Monitoring & Logging](#monitoring--logging)
7. [Security Considerations](#security-considerations)
8. [Cost Optimization](#cost-optimization)
9. [Folder Structure](#folder-structure)

---

## Architecture Overview

```
Internet
    │
    ▼
[Application Load Balancer]  ← public subnets (us-east-1a, us-east-1b)
    │  HTTPS :443 / HTTP :80
    ▼
[ECS Fargate Tasks]          ← private subnets
    │  Node.js Express app
    │  port 3000
    ▼
[RDS PostgreSQL 15]          ← private subnets (Multi-AZ in prod)
    encrypted at rest, no public access

Secrets → AWS Secrets Manager (injected at runtime by ECS)
Logs    → CloudWatch Logs (/ecs/8byte-devops-*)
Metrics → Prometheus → Grafana dashboards
```

**Key design decisions:**
- App and DB live in **private subnets** — never directly exposed to the internet.
- The **ALB** is the only public-facing component.
- All secrets are stored in **AWS Secrets Manager**, not environment variables or code.
- **ECS Fargate** removes the need to manage EC2 instances entirely.
- **Terraform modules** keep infra DRY and reusable across staging and production.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| AWS CLI | ≥ 2.x | https://aws.amazon.com/cli/ |
| Terraform | ≥ 1.5 | https://developer.hashicorp.com/terraform/install |
| Docker | ≥ 24 | https://docs.docker.com/get-docker/ |
| Node.js | 20 LTS | https://nodejs.org/ |
| Git | any | https://git-scm.com/ |

You also need an **AWS account** with permissions to create VPC, ECS, RDS, ECR, ALB, IAM roles, Secrets Manager, S3, and DynamoDB.

---

## Quick Start (Local Development)

> No AWS account needed. Everything runs on your laptop via Docker Compose.

```bash
# 1. Clone the repo
git clone https://github.com/<YOUR_USERNAME>/8byte-devops.git
cd 8byte-devops

# 2. Start all services (app + postgres + prometheus + grafana)
docker compose up --build

# 3. Test endpoints
curl http://localhost:3000/health      # → {"status":"ok"}
curl http://localhost:3000/api/users   # → list of users

# 4. Open Grafana dashboards
open http://localhost:3001             # admin / admin123

# 5. Run tests
cd app && npm ci && npm test
```

---

## Infrastructure Setup (AWS)

### Step 1 — Configure AWS CLI

```bash
aws configure
# AWS Access Key ID:     <your key>
# AWS Secret Access Key: <your secret>
# Default region:        us-east-1
# Output format:         json

# Verify
aws sts get-caller-identity
```

### Step 2 — Bootstrap Terraform remote state (run once)

```bash
chmod +x scripts/bootstrap-tfstate.sh
./scripts/bootstrap-tfstate.sh us-east-1
```

This creates:
- S3 bucket `8byte-devops-tfstate` (versioned, encrypted, private)
- DynamoDB table `8byte-devops-tf-lock` (prevents concurrent applies)

### Step 3 — Initialize and apply Terraform (staging)

```bash
cd terraform

# Download providers and modules
terraform init

# Preview changes
terraform plan -var-file="environments/staging/terraform.tfvars"

# Apply (creates all AWS resources — takes ~10 min)
terraform apply -var-file="environments/staging/terraform.tfvars"
```

After apply, note the outputs:

```bash
terraform output alb_dns_name       # your app URL
terraform output ecr_repository_url # ECR URI for docker push
```

### Step 4 — Push your first Docker image manually

```bash
# Get ECR login
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS \
    --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Build & push
ECR_URI=$(terraform output -raw ecr_repository_url)
docker build -t $ECR_URI:latest .
docker push $ECR_URI:latest

# Force ECS to pull the new image
aws ecs update-service \
  --cluster 8byte-devops-staging-cluster \
  --service  8byte-devops-staging-service \
  --force-new-deployment
```

### Step 5 — Verify deployment

```bash
ALB_URL=$(terraform output -raw alb_dns_name)
curl http://$ALB_URL/health
```

---

## CI/CD Pipeline

### GitHub Secrets to configure

Go to **GitHub repo → Settings → Secrets and variables → Actions** and add:

| Secret Name | Value |
|-------------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key (staging) |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key (staging) |
| `AWS_ACCESS_KEY_ID_PROD` | IAM user access key (production) |
| `AWS_SECRET_ACCESS_KEY_PROD` | IAM user secret key (production) |
| `SLACK_WEBHOOK_URL` | Slack incoming webhook URL |

### GitHub Environments for manual approval gate

1. Go to **Settings → Environments → New environment**
2. Create environment named **`production`**
3. Under **Required reviewers**, add yourself or your team
4. This blocks the production deploy job until a reviewer approves

### Pipeline Flow

```
PR opened
  └─► [test] Run Jest tests + integration tests
        └─► [security-scan] npm audit + Trivy filesystem scan

Merge to main
  └─► [test] → [security-scan]
        └─► [build-and-push] Build Docker image → push to ECR → Trivy image scan
              └─► [deploy-staging] Auto-deploy to ECS staging
                    └─► [deploy-production] ⏸ WAITS FOR MANUAL APPROVAL
                          └─► Deploy to ECS production
```

---

## Monitoring & Logging

### Dashboards

| Dashboard | URL (local) | Contents |
|-----------|-------------|----------|
| Infrastructure | http://localhost:3001/d/infra-overview | CPU, memory, disk, network |
| Application | http://localhost:3001/d/app-metrics | Request rate, error rate, latency percentiles, DB connections |

### Logs

- **Application logs**: CloudWatch Log Group `/ecs/8byte-devops-staging`
- **Access logs**: S3 bucket `8byte-devops-staging-alb-logs-*`
- **System logs**: Node Exporter + cAdvisor → Prometheus

View logs via AWS Console or:

```bash
aws logs tail /ecs/8byte-devops-staging --follow
```

### Key Alerts

| Alert | Threshold | Severity |
|-------|-----------|----------|
| High CPU | > 80% for 5m | Warning |
| High Memory | > 85% for 5m | Warning |
| Low Disk | < 15% free | Critical |
| High Error Rate | > 5% HTTP 5xx | Critical |
| High Latency | p95 > 1000ms | Warning |
| App Down | unreachable 1m | Critical |

---

## Security Considerations

1. **No secrets in code or env files** — All credentials stored in AWS Secrets Manager, injected at ECS task startup.
2. **Private subnets** — App and DB instances have no public IPs. Only the ALB faces the internet.
3. **Least-privilege security groups** — ALB → App → RDS, each tier only allows traffic from the tier above.
4. **Non-root container** — Dockerfile creates a dedicated `appuser` with no sudo rights.
5. **Encrypted storage** — RDS storage encrypted at rest with AES-256. S3 state bucket uses SSE-S3.
6. **Vulnerability scanning** — Trivy scans dependencies (filesystem) and the final Docker image on every build.
7. **No SSH** — ECS Fargate removes the need for SSH access. Use ECS Exec for debugging if needed.
8. **Terraform state encrypted** — S3 bucket has encryption + versioning + public access blocked.

---

## Cost Optimization

| Resource | Choice | Monthly est. |
|----------|--------|--------------|
| ECS Fargate (staging) | 0.25 vCPU / 0.5 GB, 1 task | ~$5 |
| RDS db.t3.micro (staging) | 20 GB gp3, single-AZ | ~$15 |
| ALB | 1 ALB + LCU | ~$20 |
| NAT Gateway | 1 per AZ | ~$32 |
| ECR | 10 images max (lifecycle policy) | ~$1 |
| **Total staging** | | **~$73/mo** |

**Cost-saving practices applied:**
- ECR lifecycle policy keeps only last 10 images (avoids storage bloat)
- ALB access logs auto-expire after 30 days
- Single-AZ RDS for staging (Multi-AZ only in production)
- ECS Fargate Spot can be enabled to cut compute cost by ~70%
- CloudWatch log retention set to 30 days

---

## Folder Structure

```
8byte-devops/
├── .github/
│   └── workflows/
│       ├── ci-cd.yml          # Main CI/CD pipeline
│       └── terraform.yml      # Infra plan/apply pipeline
├── terraform/
│   ├── main.tf                # Root module
│   ├── variables.tf           # All configurable parameters
│   ├── outputs.tf             # Key resource outputs
│   ├── modules/
│   │   ├── vpc/               # VPC, subnets, IGW, NAT
│   │   ├── security_groups/   # ALB, App, RDS SGs
│   │   ├── alb/               # Application Load Balancer
│   │   ├── ecs/               # ECS cluster, service, ECR
│   │   └── rds/               # PostgreSQL RDS instance
│   └── environments/
│       ├── staging/terraform.tfvars
│       └── production/terraform.tfvars
├── app/
│   ├── src/index.js           # Express application
│   ├── tests/app.test.js      # Jest unit tests
│   └── package.json
├── monitoring/
│   ├── prometheus/
│   │   ├── prometheus.yml     # Scrape config
│   │   └── alert_rules.yml    # Alerting rules
│   └── grafana/dashboards/
│       ├── infrastructure.json
│       └── application.json
├── scripts/
│   ├── bootstrap-tfstate.sh   # One-time S3/DynamoDB setup
│   ├── deploy.sh              # Manual deploy helper
│   └── init.sql               # DB seed for local dev
├── Dockerfile                 # Multi-stage build
├── docker-compose.yml         # Local dev stack
├── .gitignore
├── README.md                  # ← you are here
├── APPROACH.md
└── CHALLENGES.md
```
first trigger
