This module will create the IAM roles required for Role Vending Machine's GitHub Actions workflow.

# Notes

This bootstrap will not deploy the `assumed_role` and `oidc_provider` modules. Those two modules need to be deployed globally via AFT. Without them, RVM will not have roles to assume.
