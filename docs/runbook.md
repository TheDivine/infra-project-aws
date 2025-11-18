# Home Project Runbook

This runbook describes how to operate the Terraform-based infrastructure in
this repository: how to deploy and update stacks, how to deploy application
images, and how to handle common operational tasks.

The examples reference the `dev` environment
(`env/dev/us-east-1`), but the same patterns apply to `prod` and other
environments.

---

## 1. Prerequisites

Before running Terraform or deploying applications, ensure:

1. **AWS account and permissions**
   - You have an AWS account.
   - Your IAM user/role can create and manage:
     - VPC, subnets, route tables, IGW, NAT gateways, VPC endpoints.
     - ECS, ALB, CloudWatch Logs.
     - RDS, ElastiCache, IAM, Route53, ACM.

2. **AWS CLI configured**
   - AWS CLI v2 installed.
   - A named profile configured (default: `kwiki-test`) that matches
     `aws_profile` in `terraform.tfvars`.
   - Validate:
     ```bash
     aws sts get-caller-identity --profile kwiki-test
     ```

3. **Terraform installed**
   - Terraform version `>= 1.6.0`.

4. **Remote state backend bootstrapped**
   - S3 bucket and DynamoDB table created for Terraform state and locking,
     as documented in `instructions.md`.
   - `backend.tf` for each environment references these resources.

5. **Domain ownership**
   - You own the domain set in `domain_name` (e.g. `home-project.example.com`).
   - You are willing to let Route53 manage a hosted zone for it, or you adjust
     the shared services module to use an existing hosted zone.

---

## 2. First-time Setup: Remote State Backend

This is typically a one-time setup per AWS account/region.

1. **Create S3 bucket for state**
   - Use the commands in `instructions.md` to create
     `home-project-1-terraform-state` in `us-east-1`, enable versioning, and
     turn on SSE.

2. **Create DynamoDB table for locks**
   - Also in `instructions.md`, create the
     `home-project-1-terraform-locks` table in `us-east-1`.

3. **Verify environment backend configuration**
   - For `env/dev/us-east-1/backend.tf`, confirm:
     - `bucket`, `key`, `region`, `dynamodb_table` match the resources you
       created.

Once this is done, you should not need to recreate the bucket or table; they
are shared across many Terraform runs.

---

## 3. Deploying the Dev Environment (Infrastructure)

The dev environment example is at `env/dev/us-east-1`.

### 3.1 Configure environment variables

1. Navigate to the environment folder:

   ```bash
   cd env/dev/us-east-1
   ```

2. Edit `terraform.tfvars`:

   - **AWS configuration**
     ```hcl
     aws_region  = "us-east-1"
     aws_profile = "kwiki-test"
     ```

   - **Domain and app routing**
     ```hcl
     domain_name             = "your-real-domain.com"
     additional_domain_names = []
     app_subdomain           = "app"
     ```

   - **Application image**
     ```hcl
     app_container_image = "<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/your-app:tag"
     app_container_port  = 80
     ```

   - **App scaling and health**
     ```hcl
     app_desired_count     = 2
     app_cpu               = "512"
     app_memory            = "1024"
     app_health_check_path = "/"
     app_assign_public_ip  = false
     ```

   - **App environment (example)**
     ```hcl
     app_environment = {
       ENVIRONMENT = "dev"
     }
     ```

   - **Database defaults (dev)**
     ```hcl
     db_identifier        = "app-db-dev"
     db_name              = "appdb"
     db_username          = "appuser"          # change in real use
     db_password          = "StrongPassword1!" # change in real use
     db_instance_class    = "db.t3.micro"
     db_allocated_storage = 20
     ```

   - **Redis (dev)**
     ```hcl
     redis_name               = "app-cache-dev"
     redis_node_type          = "cache.t3.micro"
     redis_engine_version     = "7.1"
     redis_num_cache_clusters = 1
     redis_auth_token         = "" # or strong token
     ```

   Replace all placeholder secrets (`db_password`, `redis_auth_token`) with
   strong values before use.

### 3.2 Initialize Terraform

From `env/dev/us-east-1`:

```bash
terraform init -backend-config=../../backend.tf
```

This:

- Configures the remote backend (S3 + DynamoDB).
- Downloads the AWS provider.
- Finds and initializes local modules (network, shared_services, compute,
  rds, redis).

### 3.3 Plan the dev stack

```bash
terraform plan -var-file=terraform.tfvars -out=dev.tfplan
```

Check the plan for:

- New VPC, subnets, route tables, IGW, NAT gateway.
- VPC endpoints and flow logs if enabled.
- Route53 hosted zone and ACM certificate.
- ALB, ECS cluster and service, CloudWatch log groups.
- RDS instance, security group, subnet group.
- Redis replication group and supporting resources.
- A Route53 A-record for `app.<domain_name>` that aliases the ALB.

### 3.4 Apply the dev stack

```bash
terraform apply dev.tfplan
```

This may take 10–20 minutes because:

- RDS, Redis, and ECS tasks need time to provision and stabilize.
- ACM certificate must be validated via DNS.

Once the apply completes:

- The ALB is reachable.
- ECS tasks should be healthy.
- DB and Redis instances should be available in private subnets.

### 3.5 Verify success

1. Browse to `https://app.<domain_name>`:
   - If using the example Nginx image, the Nginx welcome page should load.

2. Check AWS console:
   - **Route53**: Hosted zone for `domain_name` with A-record for `app`.
   - **ACM**: Certificate for `domain_name` is in `Issued` state.
   - **EC2 -> Load Balancers**: ALB has healthy targets.
   - **ECS**: Cluster and service running tasks.
   - **RDS**: DB instance `app-db-dev` is `Available`.
   - **ElastiCache**: Redis replication group `app-cache-dev` is `Available`.

---

## 4. Deploying an Application Image

To deploy a real application instead of a sample image:

### 4.1 Build and push a container image

Example with AWS ECR:

```bash
# 1. Create an ECR repository (once)
aws ecr create-repository \
  --repository-name my-app \
  --region us-east-1

# 2. Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS \
      --password-stdin <your-account-id>.dkr.ecr.us-east-1.amazonaws.com

# 3. Build and push
docker build -t my-app:1.0.0 .
docker tag my-app:1.0.0 <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/my-app:1.0.0
docker push <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/my-app:1.0.0
```

### 4.2 Configure the app in Terraform

Edit `env/dev/us-east-1/terraform.tfvars`:

```hcl
app_container_image = "<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/my-app:1.0.0"
app_container_port  = 80
```

If your app expects environment variables:

```hcl
app_environment = {
  ENVIRONMENT = "dev"
  # e.g., application-specific settings
}
```

Later you can wire DB/Redis endpoints into `app_environment` or move
configuration into a secrets manager.

### 4.3 Roll out a new version

Whenever you push a new image tag:

1. Update `app_container_image` with the new tag.
2. Re-run:
   ```bash
   terraform plan -var-file=terraform.tfvars -out=dev.tfplan
   terraform apply dev.tfplan
   ```
3. ECS will:
   - Register a new task definition revision.
   - Replace tasks using a rolling update.
   - Maintain ALB target health checks during the rollout.

---

## 5. Scaling and Capacity Management

### 5.1 Scaling ECS

- To change the number of running tasks:

  ```hcl
  app_desired_count = 4
  ```

  Then plan/apply. ALB will automatically distribute traffic across the
  additional tasks.

- To change per-task resources:

  ```hcl
  app_cpu    = "1024" # 1 vCPU
  app_memory = "2048" # 2 GB RAM
  ```

  Plan/apply. ECS will replace tasks using the new resource settings.

### 5.2 Scaling the database

- Increase instance size:

  ```hcl
  db_instance_class = "db.t3.small"
  ```

- Increase storage:

  ```hcl
  db_allocated_storage = 50
  ```

Plan/apply these changes. Note:

- Some changes can trigger downtime or brief unavailability.
- Prefer performing them during a maintenance window if the DB is
  user-facing.

### 5.3 Scaling Redis

- Increase node size:

  ```hcl
  redis_node_type = "cache.t3.small"
  ```

- Enable multi-AZ / failover:

  ```hcl
  redis_num_cache_clusters = 2
  ```

Plan/apply. Redis operations can cause brief service impact; size and
scheduling accordingly.

---

## 6. Secrets and Configuration

### 6.1 Database credentials

Your DB credentials are currently provided via Terraform variables:

- `db_username`, `db_password`.

For dev this is acceptable, but for production:

- Prefer storing credentials in:
  - AWS Secrets Manager, or
  - SSM Parameter Store (encrypted).
- Either:
  - Inject them into the ECS task at runtime, or
  - Have the application retrieve them at startup.

If you choose to keep credentials managed by Terraform:

- Update `db_password` in `terraform.tfvars` and re-apply.
- Ensure application secrets are updated to match.

### 6.2 Redis auth token

Similarly, `redis_auth_token` is a sensitive value:

- Consider storing it in a secrets manager.
- Ensure ECS tasks have permission to read it.

### 6.3 App configuration

Best practices:

- Keep non-secret configuration (e.g. feature flags) in `app_environment`
  or an external config service.
- Keep secrets in a dedicated secrets store, not in `terraform.tfvars`.

---

## 7. Common Operations

### 7.1 Routine Terraform cycle

For any environment directory (`env/dev/us-east-1`, `env/prod/us-east-1`,
etc.):

```bash
terraform fmt -recursive
terraform init -backend-config=../../backend.tf
terraform validate
terraform plan -var-file=terraform.tfvars -out=<env>.tfplan
terraform apply <env>.tfplan
```

Use this pattern for:

- Updating app image tags.
- Tuning capacity (ECS/RDS/Redis).
- Adjusting network options or tags.

### 7.2 Rotating DB passwords

Option A (Terraform-managed):

1. Change `db_password` in `terraform.tfvars`.
2. Plan/apply.
3. Update application configuration (env vars or secrets) to match.

Option B (Console-managed):

1. Rotate password in the RDS console.
2. Update application configuration to match.
3. Optionally update `db_password` in Terraform to match the new value, or
   accept that Terraform no longer manages the password.

### 7.3 Rotating Redis auth token

Similar to DB rotation:

1. Change `redis_auth_token` in Terraform or in the console (depending on
   where it is canonical).
2. Plan/apply.
3. Ensure applications start using the new token.

### 7.4 Updating domain or hostnames

- To change the root domain:

  ```hcl
  domain_name = "new-domain.example.com"
  ```

- To change the app subdomain:

  ```hcl
  app_subdomain = "api" # results in api.<domain_name>
  ```

Plan/apply. You may also need to update name servers at your DNS registrar
to point at the new hosted zone if the domain changed.

---

## 8. Troubleshooting

### 8.1 Terraform fails with provider or STS errors

Check:

- AWS CLI:
  ```bash
  aws sts get-caller-identity --profile kwiki-test
  ```
- Backend configuration:
  - S3 bucket and DynamoDB table exist and are reachable.
  - IAM principal has permissions to use them.

If the error mentions “provider configuration not present”, see the
provider migration notes in `instructions.md`.

### 8.2 ALB returns 5xx or unhealthy targets

Steps:

1. Check the target group health in the AWS console.
2. Verify the health check path matches an actual route in your app
   (e.g. `/health`).
3. Check ECS service events for deployment failures.
4. Inspect container logs in CloudWatch Logs:
   - Log group name is defined in `modules/compute_fargate`.

### 8.3 Application cannot connect to RDS

Verify:

- Security groups:
  - ECS tasks must be allowed to reach the RDS SG on port 5432.
- Credentials:
  - Application username/password match `db_username`/`db_password`.
- Endpoint:
  - Application is using the correct RDS endpoint address.

### 8.4 Application cannot connect to Redis

Verify:

- Security groups:
  - ECS tasks must be allowed to reach the Redis SG on port 6379 (or your
    configured port).
- Endpoint:
  - Application uses `primary_endpoint` and correct port.
- Auth token:
  - If `redis_auth_token` is set, ensure the application uses it.

### 8.5 VPC flow logs not appearing

Check:

- `enable_flow_logs = true` in the environment variables.
- IAM role `aws_iam_role.flow_logs` and policy exist.
- CloudWatch log group `/aws/vpc/<vpc-id>/flow-logs` exists.

---

## 9. Destroying a Dev Environment

For disposable dev stacks, you can destroy the environment:

```bash
cd env/dev/us-east-1
terraform destroy -var-file=terraform.tfvars
```

Guidelines:

- Do **not** destroy the shared remote state bucket and DynamoDB table unless
  you intend to decommission all environments.
- For non-dev environments, consider:
  - Scaling down services.
  - Deleting specific modules selectively.
  - Taking final snapshots of RDS or Redis before destroying.

---

## 10. Extending to New Environments

To create a new environment (e.g. `prod/us-east-1`):

1. Copy an existing overlay:

   ```bash
   cp -r env/dev/us-east-1 env/prod/us-east-1
   ```

2. Update `backend.tf`:
   - Use a different `key` for state, for example:
     `prod/us-east-1/terraform.tfstate`.

3. Adjust `terraform.tfvars`:
   - Stronger instance types and sizes.
   - Different `domain_name` and `app_subdomain` if desired.
   - More conservative scaling and backup settings.

4. Initialize and deploy:

   ```bash
   cd env/prod/us-east-1
   terraform init -backend-config=../../backend.tf
   terraform plan -var-file=terraform.tfvars -out=prod.tfplan
   terraform apply prod.tfplan
   ```

This approach keeps configuration DRY while isolating state and config per
environment.

