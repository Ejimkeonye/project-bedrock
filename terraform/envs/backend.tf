terraform {
  backend "s3" {
    bucket       = "bedrock-tfstate-alt-soe-tin-025-0166"
    key          = "project-bedrock/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
