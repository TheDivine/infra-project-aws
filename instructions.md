# Create S3 bucket for state storage (CORRECTED for us-east-1)
aws s3api create-bucket \
  --bucket home-project-1-terraform-state \
  --region us-east-1

# Enable versioning on the bucket
aws s3api put-bucket-versioning \
  --bucket home-project-1-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket home-project-1-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket home-project-1-terraform-state \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name home-project-1-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

We are using location contratins for all other regions

# Create S3 bucket for state storage
aws s3api create-bucket \
  --bucket home-project-1-terraform-state \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

# Enable versioning on the bucket
aws s3api put-bucket-versioning \
  --bucket home-project-1-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket home-project-1-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket home-project-1-terraform-state \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name howme-project-1-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1

# Fixing "provider configuration not present" after moving providers
When the AWS provider block was moved from `modules/network` into the
environment overlays (`env/<stage>/<region>`), existing remote state files
kept references to the old provider address
`module.network.provider["registry.terraform.io/hashicorp/aws"]`. Terraform
needs that address to exist to refresh or destroy those resources, so `plan`
fails until the state is updated. Run the following steps **inside each
environment directory** that throws this error (for example
`env/dev/us-east-1`):

```
terraform init -reconfigure -backend-config=../../backend.tf
terraform state replace-provider \
  'module.network.provider["registry.terraform.io/hashicorp/aws"]' \
  'provider["registry.terraform.io/hashicorp/aws"]'
```

The `replace-provider` command rewrites every resource in the state file to
use the root module's AWS provider configuration. Once it succeeds, re-run
`terraform plan -var-file=../../terraform.tfvars -out=<env>.tfplan` and the
plan will complete normally.

## Additional documentation

- `docs/architecture.md` — detailed explanation of the overall AWS
  architecture, modules, and data/traffic flows.
- `docs/runbook.md` — operator runbook covering environment deployment,
  app deployments, scaling, secrets, and common operational tasks.

## Module reference

- `modules/network`: Builds the VPC, public/private subnets, NAT gateway,
  optional VPC flow logs, and optional VPC endpoints (S3, DynamoDB, SSM).
- `modules/compute_fargate`: Provisions an ECS/Fargate service behind an
  Application Load Balancer with optional HTTPS via ACM.
- `modules/rds`: Creates a PostgreSQL RDS instance, subnet group, and security
  group with sane defaults for dev/prod.
- `modules/redis`: Creates a Redis replication group (ElastiCache) plus subnet
  and security groups.
- `modules/shared_services`: Owns the Route53 hosted zone and the ACM
  certificate (DNS-validated) for ingress TLS.

Each environment overlay composes these building blocks. Dev (`env/dev/us-east-1`)
demonstrates the full stack (network + shared services + compute + data). Extend
other environments by copying the same module invocations and adjusting each
`terraform.tfvars`.
