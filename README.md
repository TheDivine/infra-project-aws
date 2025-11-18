<img width="3728" height="1672" alt="image" src="https://github.com/user-attachments/assets/e8d50ec3-a9a2-47eb-9d5a-cff282fed90f" />


# Home Project 1 – Terraform AWS Stack

This repository defines a reusable, production-style AWS infrastructure stack
using Terraform. It provides:

- A VPC with public/private subnets, NAT gateway, optional VPC endpoints, and
  optional VPC flow logs.
- Shared services for ingress: Route53 hosted zone plus DNS-validated ACM
  certificate.
- An ECS/Fargate-based compute layer behind an Application Load Balancer.
- A PostgreSQL RDS instance and a Redis ElastiCache replication group.
- Environment overlays under `env/<stage>/<region>` to compose these modules
  into full stacks (e.g. `env/dev/us-east-1`).

## Layout

- `modules/network` – VPC, subnets, IGW, NAT gateway, VPC endpoints,
  flow logs, and outputs.
- `modules/shared_services` – Route53 hosted zone and ACM certificate.
- `modules/compute_fargate` – ECS/Fargate cluster, ALB, listeners, and
  service.
- `modules/rds` – PostgreSQL RDS instance, subnet group, and security group.
- `modules/redis` – Redis ElastiCache replication group and networking.
- `env/<stage>/<region>` – Environment overlays (e.g. `dev/us-east-1`,
  `prod/us-east-1`).
- `instructions.md` – Backend bootstrap and provider-migration notes.
- `docs/architecture.md` – Detailed architecture description and Mermaid
  diagram.
- `docs/runbook.md` – Operator runbook (deploying environments, app images,
  scaling, secrets, troubleshooting).

## Getting started (dev example)

```bash
cd env/dev/us-east-1

# Initialize with remote backend
terraform init -backend-config=../../backend.tf

# Review changes
terraform plan -var-file=terraform.tfvars -out=dev.tfplan

# Apply changes
terraform apply dev.tfplan
```

Before running, update `env/dev/us-east-1/terraform.tfvars` with:

- Your AWS profile/region.
- A domain you control (`domain_name`) and an app subdomain (`app_subdomain`).
- A container image for your application (`app_container_image`).
- Database and Redis credentials suitable for the environment.

For deeper details on the architecture and day-2 operations, see:

- `docs/architecture.md`
- `docs/runbook.md`

