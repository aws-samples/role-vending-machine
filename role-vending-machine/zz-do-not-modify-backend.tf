# Variable use is not allowed, must be hard-coded to the account you want to apply to
terraform {
  backend "s3" {
    encrypt        = "true"
    bucket         = "111111111111-tf-remote-state"
    dynamodb_table = "tf-state-lock"
    key            = "github.com/<my_github_org>/role-vending-machine.git"
    region         = "us-east-1"
  }
}