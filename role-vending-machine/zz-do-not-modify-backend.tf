# Variable use is not allowed, must be hard-coded to the account you want to apply to
terraform {
  backend "s3" {
    encrypt        = "true"
    bucket         = "111111111111-tf-remote-state"
    dynamodb_table = "tf-state-lock"
    key            = "git://github.com/mygithuborg/role-vending-machine.git"
    region         = "us-east-2"
    profile        = "111111111111"
  }
}