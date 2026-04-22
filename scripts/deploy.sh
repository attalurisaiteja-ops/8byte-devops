#!/usr/bin/env bash
# ============================================================
# scripts/deploy.sh — Manual deploy helper (use CI/CD normally)
# Usage: ./scripts/deploy.sh [staging|production]
# ============================================================
set -euo pipefail

ENV="${1:-staging}"
REGION="us-east-1"
CLUSTER="8byte-devops-${ENV}-cluster"
SERVICE="8byte-devops-${ENV}-service"
ECR_REPO="8byte-devops-${ENV}"

echo "→ Deploying to: $ENV"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO}"

# Login to ECR
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Build and push
IMAGE_TAG=$(git rev-parse --short HEAD)
IMAGE_URI="${ECR_URI}:${IMAGE_TAG}"

echo "→ Building image: $IMAGE_URI"
docker build -t "$IMAGE_URI" .
docker push "$IMAGE_URI"

echo "→ Forcing ECS service update"
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --force-new-deployment \
  --region "$REGION"

echo "→ Waiting for deployment to stabilize..."
aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --region "$REGION"

echo "✅ Deployed $IMAGE_URI to $ENV"
