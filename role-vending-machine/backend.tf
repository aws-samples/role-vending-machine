# Variable use is not allowed, must be hard-coded to the account you want to apply to
terraform {
  backend "s3" {
    encrypt        = "true"
    bucket         = "<RVM HOME ACCOUNT ID>-tf-remote-state"
    dynamodb_table = "tf-state-lock"
    key            = "git://github.com/<GITHUB ORG>/<GITHUB REPO/<SUB KEY>" # This is only used to disambiguate content, it is a label
    region         = "us-west-2"
    profile        = "<RVM HOME ACCOUNT ID>"
  }
}
