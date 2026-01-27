#!/usr/bin/env bash
# Build, tag and push local image to ECR. Usage: ./scripts/build-and-push.sh <aws_account_id> <region> <repo> <tag>
set -euo pipefail

AWS_ACCOUNT_ID=$1
AWS_REGION=$2
REPO_NAME=$3
TAG=${4:-"latest"}

IMAGE_NAME=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${TAG}

echo "Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

if ! aws ecr describe-repositories --repository-names "${REPO_NAME}" --region ${AWS_REGION} >/dev/null 2>&1; then
  echo "Creating ECR repository ${REPO_NAME}..."
  aws ecr create-repository --repository-name "${REPO_NAME}" --region ${AWS_REGION} || true
fi

echo "Building docker image ${IMAGE_NAME}..."
docker build -t ${REPO_NAME}:${TAG} -f Dockerfile.template .
docker tag ${REPO_NAME}:${TAG} ${IMAGE_NAME}

echo "Pushing ${IMAGE_NAME}..."
docker push ${IMAGE_NAME}

echo "Done: ${IMAGE_NAME}"
