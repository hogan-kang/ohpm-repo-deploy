# AWS Architecture - OHPM Repo Deployment

## Current Architecture Overview

```mermaid
graph TB
    Internet[Internet] -->|HTTP:80| ALB[ALB<br/>Target Group]

    subgraph VPC[VPC]
        subgraph Public[Public Subnets]
            ALB
            NATGW[NAT Gateway]
            EIP[Elastic IP]
            EIP --> NATGW
        end

        subgraph Private[Private Subnets]
            subgraph AZ1[ap-east-1a]
                Task1[Task 1<br/>nginx:alpine<br/>256vCPU/512MB]
                MT1[Mount Target]
                Task1 -->|NFS:2049| MT1
            end

            subgraph AZ2[ap-east-1b]
                Task2[Task 2<br/>nginx:alpine<br/>256vCPU/512MB]
                MT2[Mount Target]
                Task2 -->|NFS:2049| MT2
            end
        end

        EFS[EFS Storage<br/>Regional Resource]
    end

    MT1 --> EFS
    MT2 --> EFS

    ALB -->|Forward| Task1
    ALB -->|Forward| Task2

    Task1 -.->|Outbound| NATGW --> Internet
    Task2 -.->|Outbound| NATGW --> Internet

    style ALB fill:#9f9
    style EFS fill:#ff9
    style NATGW fill:#9f9
    style Task1 fill:#99f
    style Task2 fill:#99f
```

## Network Architecture

```mermaid
graph LR
    subgraph Internet[Internet]
        DockerHub[Docker Hub]
    end

    subgraph PrivateAZ1[ap-east-1a - Private]
        Task1[ECS Task 1<br/>nginx:alpine]
    end

    subgraph PrivateAZ2[ap-east-1b - Private]
        Task2[ECS Task 2<br/>nginx:alpine]
    end

    subgraph PublicAZ1[ap-east-1a - Public]
        NAT[NAT Gateway]
        IGW[Internet Gateway]
    end

    Task1 -->|Image Pull| NAT --> IGW --> DockerHub
    Task2 -->|Image Pull| NAT --> IGW --> DockerHub

    style DockerHub fill:#4CAF50,stroke:#333,stroke-width:2px,color:#fff
    style NAT fill:#FF9800,stroke:#333,stroke-width:2px
    style Task1 fill:#2196F3,stroke:#333,stroke-width:2px,color:#fff
    style Task2 fill:#2196F3,stroke:#333,stroke-width:2px,color:#fff
```

## EFS Multi-AZ Storage

```mermaid
graph TB
    subgraph AZ1[ap-east-1a]
        Task1[ECS Task 1]
        MT1[Mount Target 1<br/>fsmt-088acd9f62667062e]
        Task1 -->|NFS:2049| MT1
    end

    subgraph AZ2[ap-east-1b]
        Task2[ECS Task 2]
        MT2[Mount Target 2<br/>fsmt-0db9e68ca0c42ef6f]
        Task2 -->|NFS:2049| MT2
    end

    subgraph EFS[EFS File System<br/>fs-058f67104d63dca7e]
        Storage1[(Data Replica 1<br/>ap-east-1a)]
        Storage2[(Data Replica 2<br/>ap-east-1b)]

        Storage1 <===>|Sync Replication| Storage2
    end

    MT1 --> Storage1
    MT2 --> Storage2

    style Storage1 fill:#FFC107,stroke:#333,stroke-width:2px
    style Storage2 fill:#FFC107,stroke:#333,stroke-width:2px
```

## Security & IAM

```mermaid
graph TB
    subgraph ECS[ECS Fargate]
        Task1[ECS Task 1]
        Task2[ECS Task 2]
    end

    subgraph Security[Security Layer]
        ALBSG[ALB Security Group<br/>ohpm-repo-dev-alb-sg]
        SG[ECS Security Group<br/>ohpm-repo-dev-ecs-sg]

        ALBIngress[ALB Inbound<br/>TCP: 80 from 0.0.0.0/0]
        ECSIngress[ECS Inbound<br/>TCP: 80 from ALB SG]
        Egress[Outbound Rules<br/>All traffic to 0.0.0.0/0]

        ALBSG --> ALBIngress
        SG --> ECSIngress
        SG --> Egress
        ALBSG -.-> Egress
    end

    subgraph IAM[IAM & Permissions]
        Role[IAM Role<br/>ohpm-repo-dev-exec-role]

        Policy[Attached Policy<br/>AmazonECSTaskExecutionRolePolicy]

        Role --> Policy

        Permissions[DockerHub Access<br/>CloudWatch Logs<br/>EFS Mount]
    end

    Task1 -->|Protected by| SG
    Task2 -->|Protected by| SG
    ALBSG -.->|Protects ALB| ALB
    ALBSG -->|Allows traffic to| SG

    Task1 -->|Assumes| Role
    Task2 -->|Assumes| Role

    Role -->|Allows| Permissions

    style ALBSG fill:#FF5722,stroke:#333,stroke-width:2px,color:#fff
    style SG fill:#9C27B0,stroke:#333,stroke-width:2px,color:#fff
    style Role fill:#3F51B5,stroke:#333,stroke-width:2px,color:#fff
```

## Component Details

### Network Layer
| Component | ID/Name | AZ | Purpose |
|-----------|---------|-----|---------|
| Public Subnet 1 | subnet-03b0f61a5d80d03e1 | ap-east-1a | NAT Gateway placement |
| Public Subnet 2 | subnet-0ac9b826ce0116170 | ap-east-1b | Reserved for HA |
| Private Subnet 1 | subnet-09fa9fb721383b4be | ap-east-1a | ECS tasks + EFS mount |
| Private Subnet 2 | subnet-0f95c02c7443c1db2 | ap-east-1b | ECS tasks + EFS mount |
| NAT Gateway | nat-0182cc0f1f3275ffb | ap-east-1a | Outbound internet access |
| Elastic IP | eip-alloc-xxx | ap-east-1a | NAT Gateway public IP |

### Compute Layer
| Component | ID/Name | Configuration |
|-----------|---------|---------------|
| ECS Cluster | ohpm-repo-dev-cluster | Fargate launch type |
| ECS Service | ohpm-repo-dev-service | Desired: 2 tasks |
| ECS Task 1 | arn:aws:ecs:ap-east-1:xxx:task/xxx | nginx:alpine (Docker Hub) |
| ECS Task 2 | arn:aws:ecs:ap-east-1:xxx:task/xxx | nginx:alpine (Docker Hub) |
| Task Definition | ohpm-repo-dev-task | 256 vCPU, 512MB RAM |

### Storage Layer
| Component | ID/Name | Location |
|-----------|---------|----------|
| EFS File System | fs-058f67104d63dca7e | Multi-AZ (regional) |
| EFS Mount Target 1 | fsmt-088acd9f62667062e | ap-east-1a (private subnet) |
| EFS Mount Target 2 | fsmt-0db9e68ca0c42ef6f | ap-east-1b (private subnet) |

### Security & IAM
| Component | ID/Name | Purpose |
|-----------|---------|---------|
| ALB Security Group | ohpm-repo-dev-alb-sg | Inbound: TCP 80 from internet |
| ECS Security Group | ohpm-repo-dev-ecs-sg | Inbound: TCP 80 from ALB SG only |
| IAM Role | ohpm-repo-dev-exec-role | ECS task execution role |

## Traffic Flow

### Outbound Traffic (Working)
```mermaid
sequenceDiagram
    participant Task as ECS Task
    participant NAT as NAT Gateway
    participant IGW as Internet Gateway
    participant DH as Docker Hub

    Task->>NAT: Pull Image: nginx:alpine
    NAT->>IGW: Route to Internet
    IGW->>DH: HTTPS Request
    DH-->>IGW: Image Response
    IGW-->>NAT: Return Data
    NAT-->>Task: Complete Pull
```

### Inbound Traffic (Working)
```mermaid
sequenceDiagram
    participant User as Internet User
    participant ALB as ALB<br/>ohpm-repo-dev-alb
    participant ECS as ECS Task
    participant EFS as EFS Storage

    User->>ALB: HTTP Request (Port 80)
    ALB->>ECS: Forward to Target Group
    ECS->>EFS: Read/Write Data
    EFS-->>ECS: Data Response
    ECS-->>ALB: HTTP Response
    ALB-->>User: Return Response
```

**Status**: ALB deployed and functional. Traffic flows from internet → ALB → ECS tasks → EFS storage.

## Cost Considerations

| Service | Monthly Cost (Approx) | Free Tier |
|---------|---------------------|-----------|
| ALB (Application Load Balancer) | ~$0.025/hour = ~$18/month | Not covered |
| ALB LCU (Load Balancer Capacity Units) | ~$0.008/LCU-hour | Not covered |
| NAT Gateway | ~$32.00 | Not covered |
| EIP | ~$2.50 | Not covered |
| EFS | ~$0.30/GB-Month | Covered (First 5GB) |
| ECS Fargate | ~$8.00 | Partially covered (750 hrs/mo) |
| NAT Gateway Data Processing | ~$0.045/GB | Not covered |

## Next Steps

1. ~~**Apply for ALB quota**~~ - ✅ Completed
2. ~~**Add ALB**~~ - ✅ Deployed
3. **Configure HTTPS** - Add SSL certificate and HTTPS listener
4. **Configure Route 53** - Set up custom domain name
5. **Deploy OHPM repo** - Replace nginx with actual OHPM repository application

## Terraform Resources

All resources are managed via Terraform:
- `main.tf` - Infrastructure definitions
- `variables.tf` - Variable declarations
- `dev.tfvars` - Development environment values
- `outputs.tf` - Output values

## Notes

- **ALB**: Public load balancer distributing traffic to ECS tasks across AZs
- **NAT Gateway**: Required for ECS tasks in private subnets to access Docker Hub
- **EFS**: Multi-AZ storage with automatic replication
- **Docker Hub**: Currently testing NAT Gateway connectivity with `nginx:alpine`
- **Security**: ECS tasks have no public IP (assign_public_ip = false), only accessible via ALB
- **Security Groups**: ECS security group only allows traffic from ALB security group, enhancing security
