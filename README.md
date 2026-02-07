# ohpm-repo-deploy

Minimal ECS + EFS test deployment tailored to fit within the AWS Free Tier where possible.

## 📦 Project Structure

```
ohpm-repo-deploy/
├── .git/                    # Git repository
├── .gitignore               # Git ignore rules
├── README.md                # Project documentation
└── terraform/               # Terraform configuration
    ├── main.tf              # Core resources (ECS/EFS)
    ├── variables.tf         # Variable definitions
    ├── providers.tf         # AWS provider config
    ├── dev.tfvars           # Development environment variables
    ├── .terraform/          # Local plugin cache (do not commit)
    └── .terraform.lock.hcl  # Provider lock file
```

## ⚡ Quick Start

### Prerequisites

```bash
# Install Terraform (>= v1.1.0)
terraform --version

# Configure AWS credentials
export AWS_REGION=ap-east-1
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret

# Or set up ~/.aws/credentials
```

### Deploy

```bash
# 1. Change into the Terraform folder
cd terraform

# 2. Initialize (download providers)
terraform init

# 3. Preview the plan
terraform plan -var-file=dev.tfvars

# 4. Apply the plan
terraform apply -var-file=dev.tfvars
# Type yes to confirm

# 5. Show outputs
terraform output
```

### Start the web service

After Terraform finishes, start an ECS task to run the web container manually:

```bash
# Get network info (or view in AWS Console)
SUBNET_ID=$(aws ec2 describe-subnets --region ap-east-1 --query 'Subnets[0].SubnetId' --output text)
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=ohpm-repo-dev-ecs-sg" --region ap-east-1 --query 'SecurityGroups[0].GroupId' --output text)

# Run a single nginx container as a Fargate task
aws ecs run-task \
  --cluster ohpm-repo-dev-cluster \
  --task-definition ohpm-repo-dev-task \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
  --count 1 \
  --region ap-east-1
```

## 📊 Configuration

Edit `terraform/dev.tfvars` to customize the deployment:

```hcl
# AWS region
aws_region      = "ap-east-1"

# Project identifiers
project         = "ohpm-repo"
env             = "dev"

# Container settings
container_port  = 80
container_image = "nginx:alpine"
```

## 💰 Cost Estimate

| Item | Estimated Cost | Notes |
|------|----------------|-------|
| ECS Fargate | $0–$4 | Small Fargate tasks may fit in the free tier for light testing |
| EFS Mount Target | $3.6 | ~ $0.12/day × 30 days |
| EFS Storage | <$1 | Small amounts of storage may remain within free usage |
| **Total** | **~$4/month** | Approximate for minimal testing |

## 📋 Resources Created

Typical resources created by this configuration include:

- Network: Security Group (HTTP/NFS), default VPC
- Compute: ECS Cluster, ECS Service, ECS Task Definition
- Storage: EFS File System, EFS Mount Target
- Permissions: IAM Role, IAM Policy

## 📝 File Summary

| File | Purpose |
|------|---------|
| main.tf | Core resources: ECS cluster, task definition, EFS, etc. |
| variables.tf | Variable declarations and defaults |
| providers.tf | AWS provider configuration and version constraints |
| dev.tfvars | Development environment variable values |
| .gitignore | Git ignore rules (protect sensitive files) |

---

**Created**: 2026-02-07  
**Recommended Terraform**: >= 1.1.0  
**AWS Provider**: >= 4.0
