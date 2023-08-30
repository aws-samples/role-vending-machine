# role-vending-machine

This repository is used to create roles for pipelines in GitHub. Be careful with this repository! It is inherently very powerful and you should add branch protection and PR reviews to ensure that unwanted changes are not made.

This is the code supplement to the Role Vending Machine APG on the [APG website](https://aws.amazon.com/prescriptive-guidance/).

## One-time setup steps

1. Determine which AWS account will be the RVM home. Ideally, this account is an infrastructure deployment account and not the management/root account.
1. Within your GitHub Organization, create a repository called `role-vending-machine` with a copy of this repository.
1. Go to `https://github.com/organizations/YOUR_ORG/settings/actions` and check `Allow GitHub Actions to create and approve pull requests` (if you want to allow the `generate_providers_and_account_vars` workflow to create PRs)
1. If you want to dynamically pull a list of your AWS Organization's accounts when the `generate_providers_and_account_vars.py` script runs, create a delegation policy in your AWS management account that provides your RVM account read-only permissions, like so:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "Statement",
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::<YOUR RVM Account ID>:root"
         },
         "Action": [
           "organizations:ListAccounts",
           "organizations:DescribeOrganization",
           "organizations:DescribeOrganizationalUnit",
           "organizations:ListRoots",
           "organizations:ListAWSServiceAccessForOrganization",
           "organizations:ListDelegatedAdministrators"
         ],
         "Resource": "*"
       }
     ]
   }
   ```
1. Update `scripts/generate_providers_and_account_vars.py` and other locations (such as the `bootstrap` folder and `providers.tf` files) with the appropriate region you operate in.
1. Update the `.github/workflows/.env` file with the account where your Role Vending Machine will live (and any other env data changes, like region)
1. Update the `role-vending-machine/backend.tf` to specify your RVM account ID as the home of the S3 backend configuration.
1. Using a method such as AFT or StackSets, deploy the `scripts\assumed_role` and the `scripts\oidc_provider` folders to each account where you want RVM to be able to create pipeline roles.
1. In the context of your RVM account, run a `terraform apply` from the `scripts/bootstrap` directory. This will create the required role for the RVM pipeline.
1. Run the `generate_providers_and_account_vars` workflow via workflow dispatch and merge its resulting PR.
1. Make sure that you have GitHub branch protection enabled for any branches that will create production roles!
1. You will now be able to create GitHub workflow roles by adding TF files to the `role-vending-machine` folder. See `example-security-inf-repo.tf` for an example to adapt.

## Role Vending Workflow

### Adding or updating a role

1. Clone the repo (_if you haven't already_):<br>`git clone <repo git address>`
2. Ensure you're on the main branch:<br>`git checkout main`
3. Pull changes from the remote (_If you haven't just cloned_):<br>`git pull`
4. Create your feature branch to make changes on:<br>`git checkout -b feature/AWS-XXXX`
5. Make new changes.
6. Add, Commit, and PR your changes to the `main` branch.

### Pull Request Review Process

Reviewers - Your work is crucial to maintaining a high level of code quality. Please consider the following while reviewing Pull Requests:

- New Terraform role file names match the repository name
- Terraform module identifiers are unique and specific to the repository
- Correct provider names are used for the repository
- Role policies do not contain hardcoded account numbers, and instead reference account IDs by the pre-generated variables (eg. `variables-accounts.tf`)
- Role policies are least-permissive
- Role policies do not contain wildcards `*` on principals
- Role policies do not authorize principals outside of this AWS Organization

## Repository Structure

```sh
.
├── .github/workflows     # <-- GitHub workflows used for Terraform Plan, Terraform Apply, and automatic provider/variable generation
├── github-workflow-roles # <-- Supporting module. Creates IAM roles with appropriate trust policy and permissions for TF GitHub Actions workflows.
├── role-vending-machine  # <-- Main module. Uses Terraform to provision roles. New role requests should be created as manifests in this folder
├── README.md             # <-- This file
└── scripts               # <-- Helpful scripts/one-off TF code (bootstrap, automatic provider/variable generation, member account roles)
```

## Auto-magical `providers.tf` and `variables-accounts.tf`

To save toil and prevent human error while modifying the `providers.tf` Terraform file to include both a terraform provider definition and a terraform variable for each account.

How it works:

- A GitHub workflow called `Generate Providers and Account Variables` runs on a daily schedule
- The script at `scripts\generate_providers_and_account_vars.py` consumes JSON formatted account lists
- Provider definitions and terraform variables files are generated and an automatic PR is cut if these files need to be updated.
