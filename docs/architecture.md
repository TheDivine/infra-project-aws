# Home Project Architecture

This document explains the architecture of the Terraform stack in this
repository, the AWS services it uses, and how they fit together to run a
production-style application.

The reference implementation is the `dev` environment in
`env/dev/us-east-1`, but the same approach applies to other environments
(`env/prod/...`) as you add them.

---

## 1. High-Level Design

Each environment (e.g. `dev/us-east-1`) builds a full application stack:

- **Network layer**
  - One VPC per environment.
  - Multiple public and private subnets spread across availability zones.
  - Internet gateway and NAT gateway for outbound connectivity.
  - Optional VPC endpoints for S3, DynamoDB, and SSM.
  - Optional VPC flow logs to CloudWatch Logs.

- **Shared services / ingress**
  - Route53 hosted zone for the application domain.
  - ACM certificate (DNS-validated) for TLS termination at the ALB.

- **Compute**
  - ECS/Fargate cluster and service.
  - Application Load Balancer (ALB) as the external entry point.
  - CloudWatch Logs for ECS task logs.

- **Data tier**
  - RDS PostgreSQL instance (private subnets).
  - Redis ElastiCache replication group (private subnets).

The environment overlay (for example `env/dev/us-east-1/main.tf`) composes
these modules into a concrete stack: network, shared services, compute, DB,
cache, and DNS records.

---

## 2. Network Layer (`modules/network`)

**Files:** `modules/network/main.tf`, `modules/network/variables.tf`,
`modules/network/outputs.tf`

The network module owns all VPC-level infrastructure for an environment.

### 2.1 Core network resources

- **VPC** (`aws_vpc.main`)
  - CIDR: `var.vpc_cidr`.
  - Default tenancy, tagged with `var.tags` and `Name = "main"`.

- **Availability zones**
  - `data "aws_availability_zones" "available"` is used to spread subnets
    across all available AZs in the region.

- **Public subnets** (`aws_subnet.public`)
  - Count: `local.public_subnet_count = length(var.public_subnet_cidrs)`.
  - AZs are assigned in round-robin fashion.
  - `map_public_ip_on_launch = true`.
  - Intended for internet-facing resources (ALB, NAT gateway).

- **Private subnets** (`aws_subnet.private`)
  - Count: `local.private_subnet_count = length(var.private_subnet_cidrs)`.
  - AZs are assigned similarly to public subnets.
  - `map_public_ip_on_launch = false`.
  - Intended for internal workloads (ECS services, RDS, Redis).

- **Internet gateway** (`aws_internet_gateway.igw`)
  - Provides internet access for public subnets.

- **Route tables**
  - Public route table (`aws_route_table.public_rt`):
    - Route `0.0.0.0/0` -> IGW.
  - Private route table (`aws_route_table.private_rt`):
    - Route `0.0.0.0/0` -> NAT gateway (for egress from private subnets).

- **NAT gateway**
  - `aws_eip.eip_nat_gw` allocates an EIP for the NAT.
  - `aws_nat_gateway.nat_gw` is placed in a public subnet.
  - Allows private subnets to reach the public internet (for updates, image
    pulls, etc.) without exposing instances directly.

### 2.2 Optional VPC endpoints

Controlled by boolean variables in `modules/network/variables.tf`:

- `enable_s3_endpoint`
- `enable_dynamodb_endpoint`
- `enable_ssm_endpoint`

When enabled:

- **S3 gateway endpoint** (`aws_vpc_endpoint.s3`)
  - Type: `Gateway`.
  - Attached to both public and private route tables.
  - Allows VPC-internal access to S3 without traversing the public internet.

- **DynamoDB gateway endpoint** (`aws_vpc_endpoint.dynamodb`)
  - Type: `Gateway`.
  - Similar to S3 endpoint, but for DynamoDB.

- **SSM interface endpoints** (`aws_vpc_endpoint.ssm`, `ssm_messages`,
  `ec2messages`)
  - Type: `Interface`.
  - Deployed into private subnets, protected by
    `aws_security_group.interface_endpoints`.
  - Allow services like SSM Agent and ECS Exec to function without public
    internet access.

These endpoints are useful for production-hardening: containers can reach
AWS APIs over private links rather than via NAT and the open internet.

### 2.3 VPC flow logs (optional)

Controlled by `enable_flow_logs`, `flow_logs_log_group_name`, and
`flow_logs_retention_in_days`.

Resources:

- `aws_cloudwatch_log_group.flow_logs`
- `aws_iam_role.flow_logs` and `aws_iam_role_policy.flow_logs`
- `aws_flow_log.vpc`

Purpose:

- Capture metadata about allowed/denied traffic in and out of the VPC.
- Useful for security investigations and network debugging.

### 2.4 Network outputs

The network module exposes identifiers so other modules can attach to the
VPC:

- `vpc_id`, `vpc_cidr_block`.
- `public_subnet_ids`, `private_subnet_ids`.
- `public_route_table_id`, `private_route_table_id`.
- `nat_gateway_id`.
- Endpoint and flow-log IDs for observability and diagnostics.

These outputs are consumed by compute, database, and cache modules in the
environment overlays.

---

## 3. Shared Services / Ingress (`modules/shared_services`)

**Files:** `modules/shared_services/main.tf`, `variables.tf`, `outputs.tf`

This module owns DNS and TLS for the application.

### 3.1 Route53 hosted zone

- `aws_route53_zone.primary`
  - Creates a hosted zone for `var.domain_name`
    (e.g. `home-project.example.com`).
  - This zone will be authoritative for the chosen domain; you must configure
    your registrar to delegate to its name servers.

### 3.2 ACM certificate with DNS validation

- `aws_acm_certificate.primary`
  - Requests a certificate for `var.domain_name` with optional SANs from
    `var.subject_alternative_names`.
  - Uses `validation_method = "DNS"`.

- `aws_route53_record.validation`
  - For each domain validation option, a DNS record is created in the hosted
    zone.

- `aws_acm_certificate_validation.primary`
  - Waits for ACM to validate the DNS records and issue the certificate.

### 3.3 Shared services outputs

- `hosted_zone_id` and `zone_name`
  - Used by the environment overlay to create application-specific DNS
    records (e.g. `app.<domain_name>`).

- `certificate_arn`
  - Used by the ALB HTTPS listener in the compute module.

---

## 4. Compute Layer: ECS/Fargate + ALB (`modules/compute_fargate`)

**Files:** `modules/compute_fargate/main.tf`, `variables.tf`, `outputs.tf`

This module encapsulates a typical ALB + ECS/Fargate microservice pattern.

### 4.1 Core components

- **ECS cluster** (`aws_ecs_cluster.this`)
  - Logical grouping for ECS services running on Fargate.

- **CloudWatch log group** (`aws_cloudwatch_log_group.this`)
  - All container logs are routed here via the `awslogs` log driver.

- **Task execution role** (`aws_iam_role.task_execution`)
  - Assumed by ECS tasks to:
    - Pull container images from ECR.
    - Write logs to CloudWatch Logs.
  - Permissions via `AmazonECSTaskExecutionRolePolicy`.

### 4.2 Security groups

- **ALB security group** (`aws_security_group.alb`)
  - Ingress:
    - HTTP 80 from `0.0.0.0/0`.
    - HTTPS 443 from `0.0.0.0/0` when a certificate is provided.
  - Egress:
    - Allow all outbound.

- **Service security group** (`aws_security_group.service`)
  - Ingress:
    - `container_port` from the ALB security group only.
  - Egress:
    - Allow all outbound (for DB, Redis, AWS APIs, etc.).

### 4.3 Load balancer and listeners

- **ALB** (`aws_lb.this`)
  - Deployed in public subnets.
  - Uses the ALB security group.

- **Target group** (`aws_lb_target_group.this`)
  - Type: `ip` (for Fargate).
  - Port: `var.container_port`.
  - Health check: configurable path, thresholds, and timeouts.

- **Listeners**
  - HTTP listener (`aws_lb_listener.http`):
    - Either forwards traffic directly to the target group, or
    - Redirects to HTTPS when a certificate is provided.
  - HTTPS listener (`aws_lb_listener.https`):
    - Only created when `var.certificate_arn` is non-empty.
    - Terminates TLS and forwards to the target group.

### 4.4 ECS task definition and service

- **Task definition** (`aws_ecs_task_definition.this`)
  - `network_mode = "awsvpc"`, `requires_compatibilities = ["FARGATE"]`.
  - CPU and memory taken from `var.cpu` and `var.memory`.
  - Container definition:
    - Image: `var.container_image`.
    - Port mapping: `var.container_port`.
    - Environment variables from `var.container_environment` map.
    - Logging via CloudWatch Logs (region autodetected from `aws_region` data
      source).

- **ECS service** (`aws_ecs_service.this`)
  - Launch type: `FARGATE`.
  - Network configuration:
    - `subnets = var.private_subnet_ids`.
    - `security_groups = [aws_security_group.service.id]`.
    - Optional `assign_public_ip`.
  - Attachments:
    - Registers tasks with the ALB target group.
  - Scaling:
    - `desired_count = var.desired_count`.
  - Optional ECS Exec:
    - Controlled via `var.enable_execute_command`.

### 4.5 Compute module inputs and outputs

Key inputs (see `modules/compute_fargate/variables.tf`):

- Networking: `vpc_id`, `public_subnet_ids`, `private_subnet_ids`.
- App config: `container_image`, `container_port`, `desired_count`,
  `cpu`, `memory`, `health_check_path`, `container_environment`.
- TLS: `certificate_arn`, `ssl_policy`.
- Operational: `assign_public_ip`, `log_retention_in_days`, `enable_execute_command`.

Key outputs (`modules/compute_fargate/outputs.tf`):

- `alb_dns_name`, `alb_zone_id` — used to create a Route53 alias.
- `service_name`, `cluster_id`, `task_definition_arn`, `target_group_arn`.

---

## 5. Data Tier: RDS PostgreSQL (`modules/rds`)

**Files:** `modules/rds/main.tf`, `variables.tf`, `outputs.tf`

This module manages a single RDS instance in private subnets.

### 5.1 Subnet group and security group

- **DB subnet group** (`aws_db_subnet_group.this`)
  - Uses a list of private subnet IDs for multi-AZ resilience.

- **Security group** (`aws_security_group.this`)
  - Ingress:
    - Allows TCP traffic on `var.port` from:
      - `var.allowed_cidr_blocks` if provided, or
      - The entire `var.vpc_cidr_block` by default.
  - Egress:
    - Allows all outbound traffic.

### 5.2 DB instance

- `aws_db_instance.this`
  - Engine: default PostgreSQL.
  - Instance class, allocated storage, port.
  - Deployed into the DB subnet group with the DB SG.
  - `publicly_accessible = false` (reachable only inside the VPC).
  - Optional multi-AZ, backup retention, maintenance window.
  - Deletion protection and snapshot controls for safety.

### 5.3 RDS module inputs and outputs

Key inputs (see `modules/rds/variables.tf`):

- Identity: `identifier`, `db_name`, `username`, `password`.
- Engine and size: `engine`, `engine_version`, `instance_class`,
  `allocated_storage`, `port`.
- Network: `subnet_ids`, `vpc_id`, `vpc_cidr_block`, `allowed_cidr_blocks`.
- Reliability / safety: `multi_az`, `backup_retention_period`,
  `maintenance_window`, `deletion_protection`, `storage_encrypted`,
  `skip_final_snapshot`, `apply_immediately`.
- `tags`.

Key outputs (`modules/rds/outputs.tf`):

- `endpoint`, `port`.
- `security_group_id`.
- `resource_id` (ARN).

Applications use the endpoint, port, DB name, and credentials to connect.

---

## 6. Data Tier: Redis ElastiCache (`modules/redis`)

**Files:** `modules/redis/main.tf`, `variables.tf`, `outputs.tf`

The Redis module provides an in-memory cache layer for the application.

### 6.1 Networking and security

- **Security group** (`aws_security_group.this`)
  - Ingress:
    - TCP on `var.port` from `var.allowed_cidr_blocks` or the entire VPC
      CIDR by default.
  - Egress:
    - Allow all outbound.

- **Subnet group** (`aws_elasticache_subnet_group.this`)
  - Uses private subnets for cache nodes.

### 6.2 Redis replication group

- `aws_elasticache_replication_group.this`
  - Engine: Redis.
  - Node type and number of cache nodes.
  - Encryption at rest and in transit can be enabled.
  - Optional auth token for authentication.
  - Multi-AZ and automatic failover when multiple nodes are configured.

### 6.3 Redis module inputs and outputs

Key inputs (see `modules/redis/variables.tf`):

- Identity: `name`.
- Network: `subnet_ids`, `vpc_id`, `vpc_cidr_block`, `allowed_cidr_blocks`.
- Engine config: `engine_version`, `node_type`, `num_cache_clusters`, `port`.
- Security / ops: `auth_token`, `parameter_group_name`, `maintenance_window`,
  `apply_immediately`, `at_rest_encryption_enabled`,
  `transit_encryption_enabled`.
- `tags`.

Key outputs (`modules/redis/outputs.tf`):

- `primary_endpoint`, `reader_endpoint`, `port`.
- `security_group_id`.

Applications use the primary endpoint and port as the Redis server for
caching, sessions, or rate limiting.

---

## 7. Environment Overlays (`env/<stage>/<region>`)

**Example:** `env/dev/us-east-1`

Each overlay:

- Declares environment-specific variables (`variables.tf`).
- Provides values in `terraform.tfvars`.
- Composes the modules in `main.tf`.

For `dev/us-east-1`:

- `module "network"`:
  - Builds the VPC, subnets, NAT, endpoints, and flow logs.

- `module "shared_services"`:
  - Creates the hosted zone and ACM certificate.

- `module "app"`:
  - Instantiates the ECS/Fargate stack behind an ALB using the network outputs
    and ACM certificate.

- `module "database"`:
  - Creates the RDS PostgreSQL instance in the private subnets.

- `module "cache"`:
  - Creates the Redis ElastiCache replication group in the private subnets.

- `aws_route53_record "app"`:
  - Creates an alias A-record for `app.<domain_name>` pointing to the ALB
    using `alb_dns_name` and `alb_zone_id`.

By copying this pattern into other environment folders (e.g.
`env/prod/us-east-1`) and adjusting `terraform.tfvars`, you can build
production and staging stacks using the same modules.

---

## 8. Data and Traffic Flow Summary

1. **User request**
   - User browses to `https://app.<domain_name>`.
   - DNS resolution hits the Route53 hosted zone.
   - Alias A-record points to the ALB.

2. **ALB to ECS**
   - ALB terminates TLS using the ACM certificate.
   - Forwards HTTP to the ECS task target group in private subnets.

3. **ECS to data tier**
   - ECS tasks, running in private subnets, connect to:
     - RDS PostgreSQL endpoint for durable data.
     - Redis primary endpoint for caching and ephemeral data.
   - Outbound calls to AWS APIs use:
     - VPC endpoints for S3/DynamoDB/SSM (if enabled), or
     - NAT gateway for general internet access.

4. **Observability**
   - ECS container logs go to CloudWatch Logs.
   - VPC Flow Logs (if enabled) capture network metadata.

This design follows AWS best practices for production workloads: private
compute and data tiers, public ingress via ALB, optional private connectivity
to AWS APIs via endpoints, and centralized logging.

---

## 9. Mermaid Architecture Diagram

The following diagram captures the main components and data flows in the
stack at a high level:

```mermaid
flowchart TB
  subgraph Internet
    User[User Browser]
  end

  subgraph Route53[Route53 Hosted Zone]
    DNS[app.domain -> ALB Alias]
  end

  subgraph VPC[VPC]
    direction TB

    subgraph Public[Public Subnets]
      ALB[ALB\nHTTP/HTTPS]
      NAT[NAT Gateway]
      IGW[Internet Gateway]
    end

    subgraph Private[Private Subnets]
      ECS[ECS Fargate\nTasks/Service]
      RDS[(RDS PostgreSQL)]
      Redis[(Redis ElastiCache)]
    end

    subgraph Endpoints[VPC Endpoints]
      EP_S3[S3 Gateway EP]
      EP_DDB[DynamoDB Gateway EP]
      EP_SSM[SSM/SSMMessages/EC2Messages\nInterface EPs]
    end
  end

  subgraph CloudWatch[CloudWatch Logs]
    CW_ECS[ECS Task Logs]
    CW_VPC[VPC Flow Logs]
  end

  User -->|HTTPS| DNS
  DNS --> ALB

  ALB -->|HTTP| ECS
  ECS -->|SQL| RDS
  ECS -->|Cache Ops| Redis

  ECS -->|AWS API Calls| EP_S3
  ECS -->|AWS API Calls| EP_DDB
  ECS -->|SSM / Exec| EP_SSM

  NAT --> IGW
  ECS -->|Internet (fallback)| NAT

  ECS --> CW_ECS
  VPC --> CW_VPC
```

You can paste this Mermaid block into any Mermaid-enabled viewer (GitHub,
VS Code with a Mermaid extension, etc.) to visualize the environment.
