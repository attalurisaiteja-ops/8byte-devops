# CHALLENGES.md — Issues Faced & Resolutions

This document records real challenges encountered during this assignment
and how each was resolved.

---

## Challenge 1: Terraform NAT Gateway Cost Spike

**Problem:** My first version provisioned a NAT Gateway in every private subnet
(4 NAT Gateways). Each NAT Gateway costs ~$32/month plus data transfer.
Four of them would cost ~$130/month just for NAT — before any compute.

**Root Cause:** I misread the Terraform docs and associated one NAT per private
subnet instead of one NAT per AZ.

**Resolution:** Refactored to one NAT Gateway per Availability Zone (2 total for
2 AZs). Private subnets in the same AZ share a single NAT Gateway. This cuts
NAT cost by 50% while maintaining high availability across AZs.

```hcl
# BEFORE (wasteful)
resource "aws_nat_gateway" "main" {
  count         = length(var.private_subnet_cidrs)  # 4 NAT GWs
  ...
}

# AFTER (correct)
resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_cidrs)   # 1 per AZ = 2 NAT GWs
  ...
}
```

**Lesson:** Always account for data transfer and per-resource charges, not just
compute costs, when designing AWS infrastructure.

---

## Challenge 2: ECS Task Failing Health Checks on Startup

**Problem:** The ECS service kept marking tasks as unhealthy and cycling them.
The ALB target group health check was failing, causing a rolling loop where
new tasks started, failed health checks, and were replaced.

**Root Cause:** The health check `startPeriod` was set to 10 seconds, but the
Node.js app took ~25 seconds to start and connect to RDS (especially on cold start
when RDS was waking up from a stopped state during dev).

**Resolution:**
1. Increased `startPeriod` to 60 seconds in the ECS task definition's `healthCheck`.
2. Added a `/health` route in the app that queries the DB before returning 200,
   so the health check actually validates DB connectivity.
3. Increased ALB health check `healthy_threshold` from 3 to 2 to allow faster
   recovery once the app is genuinely healthy.

```json
"healthCheck": {
  "command": ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"],
  "interval": 30,
  "timeout": 5,
  "retries": 3,
  "startPeriod": 60
}
```

---

## Challenge 3: GitHub Actions Could Not Push to ECR

**Problem:** The CI pipeline failed at the ECR login step with:
```
Error: denied: Your authorization token has expired. Reauthenticate and try again.
```

**Root Cause:** The IAM user attached to the GitHub secret had `ecr:GetAuthorizationToken`
permission missing. The policy only had `ecr:PutImage` and `ecr:InitiateLayerUpload`.

**Resolution:** Updated the IAM policy for the CI user to include the full set of
ECR permissions required for a push:

```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload",
    "ecr:PutImage"
  ],
  "Resource": "*"
}
```

**Lesson:** Test IAM permissions using `aws iam simulate-principal-policy` before
running the full pipeline. The AWS docs list the exact permissions needed for ECR push.

---

## Challenge 4: RDS Password in Terraform State

**Problem:** When I first wrote the RDS module, I hardcoded the `db_password`
in `terraform.tfvars`. Terraform stores this in plain text in the state file.
Even with S3 encryption, this is bad practice — anyone with S3 read access
can see the password.

**Resolution:** Used `random_password` resource + AWS Secrets Manager:
1. Terraform generates a random password (never in tfvars).
2. Password is written to Secrets Manager as a JSON blob (username, password, host).
3. ECS task definition references the Secrets Manager ARN, not the value.
4. The state file still contains the password, but it's now in an encrypted S3 bucket
   with versioning and access restricted to a single IAM role.

**Long-term fix:** Use Terraform Vault provider or AWS SSM Parameter Store with
`SecureString` to keep the generated password out of Terraform state entirely.

---

## Challenge 5: Docker Build Context Was Sending node_modules to Docker Daemon

**Problem:** `docker build` was extremely slow (~3 minutes) even for small code changes.

**Root Cause:** The `node_modules` directory (200MB+) was being sent to the Docker
build context every time, even though the Dockerfile's `COPY` step uses
`package*.json` first and only copies `src/`.

**Resolution:** Added a `.dockerignore` file:

```
node_modules
app/node_modules
.git
*.log
coverage/
.env
```

Build time dropped from ~3 minutes to ~20 seconds.

**Lesson:** Always add `.dockerignore` before the first `docker build`. It should
mirror `.gitignore` for build-irrelevant files.

---

## Challenge 6: Prometheus Could Not Scrape App in Docker Compose

**Problem:** Prometheus showed `connection refused` when scraping `app:3000/metrics`.
The app was running but had no `/metrics` endpoint.

**Root Cause:** A standard Express app does not expose Prometheus metrics by default.
The `prom-client` npm package needs to be added and a `/metrics` route configured.

**Resolution:** Added `prom-client` to the app:

```javascript
const client = require('prom-client');
const register = new client.Registry();
client.collectDefaultMetrics({ register });

app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

This exposes default Node.js metrics (event loop lag, memory heap, GC pauses)
plus any custom metrics added later.

---

## Challenge 7: Manual Production Approval Not Blocking in GitHub Actions

**Problem:** The `deploy-production` job ran immediately without waiting for a
reviewer, despite setting the `environment: production` field.

**Root Cause:** I had created the `production` environment in GitHub but had
not added any required reviewers under the "Protection rules" section.
An environment with no reviewers does not block anything.

**Resolution:**
1. GitHub → Repository → Settings → Environments → production
2. Checked "Required reviewers"
3. Added my own GitHub username as a required reviewer
4. Re-ran the pipeline — it now pauses and shows a "Review deployments" button

**Lesson:** Environment-level protection rules in GitHub must be explicitly configured
with at least one reviewer. Creating the environment alone is not enough.

---

## Summary

| # | Challenge | Root Cause | Resolution |
|---|-----------|------------|------------|
| 1 | NAT Gateway cost spike | Miscounted NAT GWs | 1 NAT per AZ, not per subnet |
| 2 | ECS health check loop | `startPeriod` too short | Increased to 60s + proper `/health` route |
| 3 | GitHub → ECR auth failure | Missing IAM permission | Added `ecr:GetAuthorizationToken` |
| 4 | DB password in state | Hardcoded in tfvars | `random_password` + Secrets Manager |
| 5 | Slow Docker builds | No `.dockerignore` | Added `.dockerignore` |
| 6 | Prometheus scrape error | No `/metrics` endpoint | Added `prom-client` to app |
| 7 | Approval gate not blocking | No reviewer configured | Added required reviewer in GitHub env |
