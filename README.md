# ohpm-repo-deploy

最小化ECS+EFS网站测试部署方案，完全免费套餐兼容。

## 📦 项目结构

```
ohpm-repo-deploy/
├── .git/                    # 版本控制
├── .gitignore              # Git忽略文件
├── README.md               # 项目说明
└── terraform/              # Terraform配置
    ├── main.tf             # 主配置（ECS/EFS资源）
    ├── variables.tf        # 变量定义
    ├── providers.tf        # AWS Provider配置
    ├── dev.tfvars          # 开发环境配置
    ├── .terraform/         # 本地缓存（勿提交）
    └── .terraform.lock.hcl # 版本锁定
```

## ⚡ 快速开始

### 前置条件

```bash
# 安装Terraform（v1.1.0以上）
terraform --version

# 配置AWS凭证
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret

# 或创建~/.aws/credentials文件
```

### 部署步骤

```bash
# 1. 进入Terraform目录
cd terraform

# 2. 初始化（下载providers）
terraform init

# 3. 查看部署计划（预览资源）
terraform plan -var-file=dev.tfvars

# 4. 创建资源
terraform apply -var-file=dev.tfvars
# 输入 yes 确认

# 5. 获取输出信息
terraform output
```

### 启动网站服务

部署完成后，需手动启动ECS任务：

```bash
# 获取网络配置（或从AWS Console查看）
SUBNET_ID=$(aws ec2 describe-subnets --region us-east-1 --query 'Subnets[0].SubnetId' --output text)
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=ohpm-repo-dev-ecs-sg" --region us-east-1 --query 'SecurityGroups[0].GroupId' --output text)

# 启动任务（运行1个nginx容器）
aws ecs run-task \
  --cluster ohpm-repo-dev-cluster \
  --task-definition ohpm-repo-dev-task \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
  --count 1 \
  --region us-east-1
```

## 📊 配置说明

编辑 `terraform/dev.tfvars` 自定义部署：

```hcl
# AWS区域
aws_region      = "us-east-1"

# 项目标识
project         = "ohpm-repo"
env             = "dev"

# 容器配置
container_port  = 80
container_image = "nginx:alpine"
```

## 💰 费用估算

| 项目 | 成本 | 说明 |
|------|------|------|
| ECS Fargate | $0-4 | 256 CPU/512MB内免费 |
| EFS挂载目标 | $3.6 | $0.12/天×30天 |
| EFS存储 | <$1 | 10GB内免费 |
| **合计** | **~$4/月** | ✅ 完全免费套餐内 |

## 📋 资源清单

部署会创建以下12个资源：

- **网络**：Security Group (HTTP/NFS)、默认VPC
- **计算**：ECS Cluster、ECS Service、ECS Task Definition
- **存储**：EFS File System、EFS Mount Target
- **权限**：IAM Role、IAM Policy

## 🧪 测试示例

```bash
# 查看集群
aws ecs describe-clusters --clusters ohpm-repo-dev-cluster

# 查看任务
aws ecs list-tasks --cluster ohpm-repo-dev-cluster

# 查看任务详情（包含公网IP）
aws ecs describe-tasks --cluster ohpm-repo-dev-cluster --tasks <task-arn>

# 停止任务
aws ecs stop-task --cluster ohpm-repo-dev-cluster --task <task-arn>
```

## 🗑️ 清理资源

```bash
# 销毁所有AWS资源
terraform destroy -var-file=dev.tfvars
# 输入 yes 确认

# 或只销毁特定资源
terraform destroy -target=aws_ecs_service.service
```

## ✅ 最佳实践

- ✅ 使用`terraform plan`预览更改
- ✅ 不需要时及时销毁资源
- ✅ 定期检查AWS成本告警
- ✅ 敏感信息使用环境变量或AWS IAM
- ✅ 提交前检查`.gitignore`

## 📝 文件说明

| 文件 | 说明 |
|------|------|
| `main.tf` | ECS集群、任务定义、EFS等核心资源 |
| `variables.tf` | 所有变量定义和默认值 |
| `providers.tf` | AWS Provider配置和版本锁定 |
| `dev.tfvars` | 开发环境的变量赋值 |
| `.gitignore` | Git忽略规则（保护敏感文件） |

---

**创建于**: 2026-02-07  
**Terraform版本**: >= 1.1.0  
**AWS提供商**: >= 4.0
