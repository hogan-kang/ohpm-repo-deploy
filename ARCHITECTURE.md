# AWS Architecture - OHPM Repo Deployment

## Current Architecture Overview

```mermaid
graph TB
    Internet[Internet] -->|HTTPS Pending| ALB[ALB<br/>Not Available]

    subgraph VPC[VPC: vpc-07fb5a10e41318e7a]
        subgraph PublicSubnets[Public Subnets]
            PubSub1[ap-east-1a<br/>subnet-03b0f61a5d80d03e1]
            PubSub2[ap-east-1b<br/>subnet-0ac9b826ce0116170]

            NATGW[NAT Gateway<br/>nat-0182cc0f1f3275ffb]
            EIP[Elastic IP]

            EIP --> NATGW
            NATGW -->|Outbound| Internet

            PubSub1 --> NATGW
            PubSub2 -.->|Reserved| PubSub2
        end

        subgraph PrivateSubnets[Private Subnets]
            PrivSub1[ap-east-1a<br/>subnet-09fa9fb721383b4be<br/>172.31.128.0/20]
            PrivSub2[ap-east-1b<br/>subnet-0f95c02c7443c1db2<br/>172.31.144.0/20]

            subgraph AZ1[Availability Zone 1]
                Task1[ECS Task 1<br/>nginx:alpine<br/>Port: 80]
                MountTarget1[EFS Mount Target 1<br/>fsmt-088acd9f62667062e]

                Task1 -->|NFS:2049| MountTarget1
                Task1 -.->|Outbound via NAT| NATGW
            end

            subgraph AZ2[Availability Zone 2]
                Task2[ECS Task 2<br/>nginx:alpine<br/>Port: 80]
                MountTarget2[EFS Mount Target 2<br/>fsmt-0db9e68ca0c42ef6f]

                Task2 -->|NFS:2049| MountTarget2
                Task2 -.->|Outbound via NAT| NATGW
            end

            PrivSub1 --> AZ1
            PrivSub2 --> AZ2
        end

        subgraph Storage[Storage Layer]
            EFS[EFS File System<br/>fs-058f67104d63dca7e<br/>Multi-AZ Storage]

            MountTarget1 --> EFS
            MountTarget2 --> EFS
        end

        subgraph Shared[Shared Services]
            ECSCluster[ECS Cluster<br/>ohpm-repo-dev-cluster]
            ECSService[ECS Service<br/>ohpm-repo-dev-service<br/>Desired: 2 tasks]
            SG[Security Group<br/>ohpm-repo-dev-ecs-sg<br/>Ingress: TCP 80<br/>Egress: All]
            IAMRole[IAM Role<br/>ohpm-repo-dev-exec-role]

            Task1 -.->|Managed by| ECSService
            Task2 -.->|Managed by| ECSService
            ECSService -.->|Part of| ECSCluster

            Task1 -.->|Protected by| SG
            Task2 -.->|Protected by| SG
            MountTarget1 -.->|Protected by| SG
            MountTarget2 -.->|Protected by| SG

            Task1 -.->|Uses| IAMRole
            Task2 -.->|Uses| IAMRole
        end
    end

    style Internet fill:#f9f,stroke:#333,stroke-width:2px
    style ALB fill:#f66,stroke:#f00,stroke-width:2px
    style NATGW fill:#9f9,stroke:#333,stroke-width:2px
    style EFS fill:#ff9,stroke:#333,stroke-width:2px
    style Task1 fill:#99f,stroke:#333,stroke-width:2px
    style Task2 fill:#99f,stroke:#333,stroke-width:2px
```

## Network Architecture

```mermaid
graph LR
    subgraph Internet[Internet]
        DockerHub[Docker Hub]
        ECRPublic[ECR Public]
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

    Task1 -.->|Optional| ECRPublic
    Task2 -.->|Optional| ECRPublic

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
        SG[Security Group<br/>ohpm-repo-dev-ecs-sg<br/>sg-01485d4d93afcaa14]

        Ingress[Inbound Rules<br/>TCP: 80 from 0.0.0.0/0]
        Egress[Outbound Rules<br/>All traffic to 0.0.0.0/0]

        SG --> Ingress
        SG --> Egress
    end

    subgraph IAM[IAM & Permissions]
        Role[IAM Role<br/>ohpm-repo-dev-exec-role]

        Policy[Attached Policy<br/>AmazonECSTaskExecutionRolePolicy]

        Role --> Policy

        ECR[ECR Pull<br/>DockerHub Access<br/>CloudWatch Logs]
    end

    Task1 -->|Protected by| SG
    Task2 -->|Protected by| SG

    Task1 -->|Assumes| Role
    Task2 -->|Assumes| Role

    Role -->|Allows| ECR

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
| Security Group | sg-01485d4d93afcaa14 | ECS + EFS (ohpm-repo-dev-ecs-sg) |
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

### Inbound Traffic (Pending)
```mermaid
sequenceDiagram
    participant User as Internet User
    participant ALB as ALB<br/>(Not Available)
    participant ECS as ECS Task
    participant EFS as EFS Storage

    User->>ALB: HTTPS Request
    Note over ALB: ⚠️ Quota Not Approved
    ALB-xECS: Cannot Forward
    ECS-xEFS: Cannot Serve
```

**Status**: ALB quota not approved. Waiting for AWS Support approval.

## Cost Considerations

| Service | Monthly Cost (Approx) | Free Tier |
|---------|---------------------|-----------|
| NAT Gateway | ~$32.00 | Not covered |
| EIP | ~$2.50 | Not covered |
| EFS | ~$0.30/GB-Month | Covered (First 5GB) |
| ECS Fargate | ~$8.00 | Partially covered (750 hrs/mo) |
| NAT Gateway Data Processing | ~$0.045/GB | Not covered |

## Next Steps

1. **Apply for ALB quota** - Submit request to AWS Support
2. **Add ALB** - Once approved, deploy Application Load Balancer
3. **Configure Route 53** - Set up domain name
4. **Update ECS Service** - Attach target group to ALB

## Terraform Resources

All resources are managed via Terraform:
- `main.tf` - Infrastructure definitions
- `variables.tf` - Variable declarations
- `dev.tfvars` - Development environment values
- `outputs.tf` - Output values

## Notes

- **NAT Gateway**: Required for ECS tasks in private subnets to access Docker Hub
- **EFS**: Multi-AZ storage with automatic replication
- **Docker Hub**: Currently testing NAT Gateway connectivity with `nginx:alpine`
- **Security**: ECS tasks have no public IP (assign_public_ip = false)
