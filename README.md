# ohpm-repo-deploy

Purpose: provide examples to provision AWS infra with Terraform and deploy `ohpm-repo` to ECS Fargate using Docker + GitHub Actions.

What is included
- `infra/terraform/` - Terraform starter templates (VPC, ALB, ECR, ECS Fargate task/service)
- `Dockerfile.template` - example Dockerfile (replace according to your app's language)
- `scripts/build-and-push.sh` - helper to build locally and push to ECR
- `.github/workflows/app-deploy.yml` - Github Actions job to build, push image to ECR and update ECS service
- `.github/workflows/infra-deploy.yml` - Terraform plan CI

Quick start (local):

1) Prepare AWS credentials (local dev):

```bash
export AWS_REGION=ap-northeast-1
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

2) Build & push image locally (example):

```bash
# create ECR repo first or let script create it
chmod +x scripts/build-and-push.sh
./scripts/build-and-push.sh <AWS_ACCOUNT_ID> ${AWS_REGION} ohpm-repo:dev
```

3) Terraform init & apply (local testing):

```bash
cd infra/terraform
# optionally enable backend in backend.tf
terraform init
terraform apply -var="container_image=<ACCOUNT>.dkr.ecr.${AWS_REGION}.amazonaws.com/ohpm-repo:dev"
```

GitHub Actions notes
- Add these repository secrets:
	- AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (or use OIDC + role)
	- AWS_REGION
	- AWS_ACCOUNT_ID
	- ECR_REPOSITORY
	- ECS_CLUSTER_NAME, ECS_SERVICE_NAME, ECS_TASK_FAMILY, ECS_EXEC_ROLE, CONTAINER_NAME
	- (optional) AWS_OIDC_ROLE if using OIDC

Security & production notes
- Use remote state backend (S3 + DynamoDB) for team workflows; edit `infra/terraform/backend.tf` and create bucket & table before enabling.
- Protect `infra` apply with PR reviews or manual approval; prefer GitHub environment approvals for terraform apply.
- Use least-privilege IAM roles for CI and ECS.

Next steps suggested
- Replace `Dockerfile.template` with a real Dockerfile for `ohpm-repo` (Node/Java/python etc.)
- Add CloudWatch alarms and dashboards
- Add health-check endpoints and readiness/liveness probes in application
