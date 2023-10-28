provider "aws" {
  region = var.aws_region
}

terraform {
  required_version = ">= 0.12.31"
}
