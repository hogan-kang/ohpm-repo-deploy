# dev.tfvars - development variables (safe to commit if no secrets included)
aws_region      = "ap-east-1"
project         = "ohpm-repo"
env             = "dev"
container_port  = 8080
desired_count   = 1
# Replace <AWS_ACCOUNT_ID> with your account id before using
container_image = "<AWS_ACCOUNT_ID>.dkr.ecr.ap-east-1.amazonaws.com/ohpm-repo:dev"
use_default_vpc = true

# public_subnets/private_subnets not needed when use_default_vpc = true
