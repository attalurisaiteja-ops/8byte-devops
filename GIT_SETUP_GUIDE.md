# GIT_SETUP_GUIDE.md
# Complete step-by-step guide: from zero to a submitted GitHub repo

---

## STEP 1 — Create a GitHub Account (skip if you have one)

1. Go to https://github.com
2. Click "Sign up"
3. Enter your email, create a password, pick a username
4. Verify your email

---

## STEP 2 — Create a New Public Repository on GitHub

1. Log in to GitHub
2. Click the **+** icon (top-right) → **New repository**
3. Fill in:
   - Repository name: `8byte-devops`
   - Description: `DevOps assignment — Terraform, ECS, RDS, CI/CD, Monitoring`
   - Visibility: **Public** ✅ (required for submission)
   - Do NOT initialize with README (we have our own)
4. Click **Create repository**
5. Copy the repo URL shown (e.g. `https://github.com/YOUR_USERNAME/8byte-devops.git`)

---

## STEP 3 — Install Git on Your Machine

**Windows:**
- Download from https://git-scm.com/download/win
- Run installer, accept all defaults

**macOS:**
```bash
brew install git
```

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install git -y
```

**Verify:**
```bash
git --version
# git version 2.x.x
```

---

## STEP 4 — Configure Git Identity (one-time setup)

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

---

## STEP 5 — Initialize the Local Repository

```bash
# Navigate to the project folder (wherever you extracted the zip)
cd 8byte-devops

# Initialize git
git init

# Add the GitHub remote
git remote add origin https://github.com/YOUR_USERNAME/8byte-devops.git
```

---

## STEP 6 — Make Your First Commit

```bash
# Stage everything
git add .

# Check what's staged (should show all project files)
git status

# Commit
git commit -m "feat: initial commit — complete DevOps assignment

- Part 1: Terraform IaC (VPC, ECS, RDS, ALB, Security Groups)
- Part 2: GitHub Actions CI/CD pipeline with manual prod approval
- Part 3: Prometheus + Grafana monitoring with 2 dashboards
- Part 4: README, APPROACH.md, CHALLENGES.md documentation"
```

---

## STEP 7 — Push to GitHub

```bash
# Rename default branch to main
git branch -M main

# Push
git push -u origin main
```

If prompted for credentials:
- Username: your GitHub username
- Password: use a **Personal Access Token** (NOT your GitHub password)
  - Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
  - Click "Generate new token (classic)"
  - Set expiration to 90 days
  - Check scopes: `repo` (full control)
  - Copy the token and use it as your password

---

## STEP 8 — Set Up GitHub Actions Secrets

1. Go to your repo on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each:

```
Name: AWS_ACCESS_KEY_ID
Value: (your AWS IAM user access key)

Name: AWS_SECRET_ACCESS_KEY
Value: (your AWS IAM user secret key)

Name: AWS_ACCESS_KEY_ID_PROD
Value: (production IAM key — can be same as above for assignment)

Name: AWS_SECRET_ACCESS_KEY_PROD
Value: (production IAM secret — can be same as above for assignment)

Name: SLACK_WEBHOOK_URL
Value: (your Slack webhook, or use a dummy value: https://hooks.slack.com/test)
```

---

## STEP 9 — Set Up GitHub Environments (Manual Approval Gate)

1. Go to **Settings** → **Environments** → **New environment**
2. Name: `staging` → Click **Configure environment** → Save
3. Create another: `production`
4. For `production`:
   - Check ✅ **Required reviewers**
   - Add your GitHub username
   - Click **Save protection rules**

---

## STEP 10 — Trigger Your First Pipeline Run

```bash
# Make a small change to trigger CI
echo "# Trigger CI" >> README.md
git add README.md
git commit -m "ci: trigger first pipeline run"
git push origin main
```

Then go to GitHub → **Actions** tab to watch it run.

---

## STEP 11 — Verify Pipeline Succeeded

Your Actions tab should show:
```
✅ CI / CD Pipeline
   ✅ Unit & Integration Tests
   ✅ Security Scan
   ✅ Build & Push Docker Image
   ✅ Deploy → Staging
   ⏸ Deploy → Production  ← waiting for your approval
```

Click "Review deployments" to approve the production deploy.

---

## STEP 12 — Final Repo Structure Check

Run this to verify all files are committed:

```bash
git log --oneline
git ls-files | head -50
```

Your repo should contain:
```
.github/workflows/ci-cd.yml
.github/workflows/terraform.yml
.github/workflows/pr-check.yml
terraform/main.tf
terraform/variables.tf
terraform/outputs.tf
terraform/modules/vpc/
terraform/modules/security_groups/
terraform/modules/alb/
terraform/modules/ecs/
terraform/modules/rds/
terraform/environments/staging/terraform.tfvars
terraform/environments/production/terraform.tfvars
app/src/index.js
app/tests/app.test.js
app/package.json
monitoring/prometheus/prometheus.yml
monitoring/prometheus/alert_rules.yml
monitoring/grafana/dashboards/infrastructure.json
monitoring/grafana/dashboards/application.json
docker-compose.yml
Dockerfile
.gitignore
.env.example
README.md
APPROACH.md
CHALLENGES.md
scripts/bootstrap-tfstate.sh
scripts/deploy.sh
scripts/init.sql
```

---

## STEP 13 — Submission

Share with 8byte:
1. **GitHub repo URL**: `https://github.com/YOUR_USERNAME/8byte-devops`
2. Confirm `README.md`, `APPROACH.md`, and `CHALLENGES.md` are visible on GitHub
3. Share a screenshot of a successful GitHub Actions run

---

## Useful Git Commands Reference

```bash
# Check current status
git status

# See commit history
git log --oneline --graph

# Create and switch to a new branch (for PRs)
git checkout -b feature/my-change

# Push a branch
git push origin feature/my-change

# Undo last commit (keep files)
git reset --soft HEAD~1

# See what changed
git diff

# Pull latest changes
git pull origin main
```
