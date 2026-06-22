terraform {
  backend "s3" {
    bucket         = "tripplan-terraform-state-nptuyenn-20260622"
    key            = "envs/dev/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "tripplan-terraform-locks"
    encrypt        = true
  }
}
