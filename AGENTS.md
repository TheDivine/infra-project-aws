# Repository Guidelines

## Project Structure & Module Organization
Root `main.tf` hosts the canonical VPC/subnet stack; shared inputs live in `variables.tf`, while operator defaults sit in `terraform.tfvars`. Remote state wiring is in `backend.tf`—update bucket, key, region, and Dynamo table before `terraform init`. Environment overlays live in `env/<stage>/<region>/` (e.g., `env/dev/us-east-1/main.tf`) and call `modules/network`; add new reusable code under `modules/<name>/` with co-located variable/output files. Leave generated folders such as `.terraform/` and `terraform.tfstate*` untracked.

## Build, Test, and Development Commands
- `cd env/dev/us-east-1 && terraform init -backend-config=../../backend.tf` — pins providers and S3/DynamoDB backend.
- `terraform fmt -recursive` — enforces formatting.
- `terraform validate` — schema and reference checks.
- `terraform plan -var-file=../../terraform.tfvars -out=dev.tfplan` — produces the diff that reviewers sign off on.
- `terraform apply dev.tfplan` — applies the reviewed plan; never apply without a saved plan file.
- `terraform destroy -var-file=../../terraform.tfvars` — removes ephemeral stacks after testing.

## Coding Style & Naming Conventions
Let `terraform fmt` control indentation (two spaces) and alignment. Prefer snake_case variables and lowercase hyphenated AWS `Name` tags (`dev-public-rt`). Keep shared metadata in locals such as `local.default_tags`, and only expose variables a module truly needs. Order block arguments predictably (identifiers → networking → tags) and add brief comments when values are environment-specific.

## Testing Guidelines
Treat `terraform fmt`, `validate`, and `plan -detailed-exitcode` as the default test suite. Plan every environment affected by a change (dev today, prod once populated) and attach the plan output to code review. Use `terraform plan -refresh-only` before applying networking updates to detect drift, and `terraform plan -target=module.network` for surgical checks when iterating quickly.

## Commit & Pull Request Guidelines
Because this folder is not yet an initialized Git repo, follow Conventional Commits for clarity (`feat(network): add nat gateway eip`). Keep one logical change per PR, describe intent and blast radius, and link any issue IDs. Include the latest `terraform fmt`, `validate`, and `plan` results (command plus summary) in the PR description and call out follow-up tasks such as backend migrations.

## Security & Configuration Tips
Keep credentials out of `.tf` files; rely on the `kwiki-test` profile set in `terraform.tfvars` or export `AWS_PROFILE`. Ensure the remote-state S3 bucket and DynamoDB table defined in `backend.tf` exist before initializing, and never hand-edit `terraform.tfstate*`. Grant only least-privilege IAM rights required by `modules/network`, and store future secrets in AWS SSM or environment variables rather than version control.
