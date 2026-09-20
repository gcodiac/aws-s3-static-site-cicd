# Terraform state lives in S3, so every pipeline run (and your laptop) sees the same state.
#
# The bucket and region cannot use variables here, so they are passed at init:
#   terraform init -backend-config="bucket=<state-bucket>" -backend-config="region=<region>"
terraform {
  backend "s3" {
    key          = "cloud-launchpad/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # S3 native locking, no DynamoDB table needed (Terraform 1.10+)
  }
}
