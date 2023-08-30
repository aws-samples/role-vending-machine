# Variable use is not allowed, must be hard-coded to the account you want to apply to
terraform {
  backend "s3" {
    encrypt        = "true"
    bucket         = "<RVM HOME ACCOUNT ID>-tf-remote-state"
    dynamodb_table = "tf-state-lock"
    key            = "git://github.com/realmidx-platform/realmidx-foundation.git/cis_alerting"
    region         = "us-west-2"
    profile        = "<RVM HOME ACCOUNT ID>"
  }
}