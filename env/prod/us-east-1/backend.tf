// Terraform backend configuration
// IMPORTANT — Names here must match real AWS resources you create:
// - S3 bucket `bucket` must exist and be globally unique.
// - DynamoDB table `dynamodb_table` must exist in the same region.
// - `region` must match where you created the bucket and table.
// If you change any of these names, update them in this file AND create
// the corresponding resources manually before `terraform init`.
// See: inital-test.md (Appendix A) for step-by-step setup.
terraform {
  backend "s3" {
    bucket         = "home-project-1-terraform-state"
    key            = "prod/us-east-1/terraform.tfstate"
    region         = "us-east-1"
    profile        = "kwiki-test"
    dynamodb_table = "home-project-1-terraform-locks"
    encrypt        = true
  }
}
