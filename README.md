# role-vending-machine

This repository is used to create roles for pipelines in GitHub. Be careful with this repository! It is inherently very powerful and you should add branch protection and PR reviews to ensure that unwanted changes are not made.

This is the code supplement to an upcoming [Amazon Prescriptive Guidance](https://aws.amazon.com/prescriptive-guidance/) article. Full details are included in that guide.

## Role Vending Workflow

### Adding or updating a role

1. Clone the repo (_if you haven't already_):<br>`git clone <repo git address>`
2. Ensure you're on the main branch:<br>`git checkout main`
3. Pull changes from the remote (_If you haven't just cloned_):<br>`git pull`
4. Create your feature branch to make changes on:<br>`git checkout -b feature/AWS-XXXX`
5. Make new changes by adding a new `.tf` file to the `role-vending-machine` subfolder, or updating an existing file. For an example, see the `example-security-inf-repo.tf.example` file.
6. Add, Commit, and PR your changes to the `main` branch.

### Pull Request Review Process

Reviewers - Your work is crucial to maintaining a high level of code quality. Please consider the following while reviewing Pull Requests:

- New Terraform role file names match the repository name
- Terraform module identifiers are unique and specific to the repository
- Correct provider names are used for the repository
- Role policies do not contain hardcoded account numbers, and instead reference account IDs by the pre-generated variables
- Role policies are least-permissive
- Role policies do not contain wildcards `*` on principals
- Role policies do not authorize principals outside of this AWS Organization

## One-time initial deployment setup steps

0. Determine which account will be the RVM home. Ideally, this account is an infrastructure deployment account and not the management/root account.
1. Go to `https://github.com/organizations/YOUR_ORG/settings/actions` and check `Allow GitHub Actions to create and approve pull requests` (if you want to allow the `generate_providers_and_account_vars` workflow to create PRs)
2. If you want to dynamically pull a list of your Organization's accounts when the `generate_providers_and_account_vars.py` script runs, create a delegation policy in your management account that provides your RVM account read-only permissions, like so:
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
3. Update `scripts/generate_providers_and_account_vars.py` and other locations (such as the `bootstrap` folder) with the appropriate region you operate in
4. Update the `zz-do-not-modify` TF files in the `role-vending-machine` directory to match the correct backend for your Terraform state (note: the "do not modify" directive is aimed at developers using this repository; RVM administrators may modify these manifests).
5. Update the `.github/workflows/.env` file with the account where your Role Vending Machine will live (and any other env data changes, like region)
6. In the context of your RVM account, run a `terraform apply` from the `scripts/bootstrap` directory. This will create the required role for the RVM pipeline.
7. Using a method such as AFT or StackSets, deploy the IAM role in the `scripts\assumed_role` folder to each account where you want RVM to be able to create pipeline roles.
8. Run the `generate_providers_and_account_vars` workflow via workflow dispatch.
9. You will now be able to create GitHub workflow roles by adding TF files to the `role-vending-machine` folder.


## Auto-magical `providers.tf` and `variables-accounts-<env>.tf`

To save toil and prevent human error while modifying the `providers.tf` Terraform file to include both a terraform provider definition and a terraform variable for each account.

How it works:

- A GitHub workflow called `Generate Providers and Account Variables` runs on a daily schedule
- The script at `scripts\generate_providers_and_account_vars.py` consumes JSON formatted account lists
- Provider definitions and terraform variables files are generated and an automatic PR is cut if these files need to be updated.
- Because RVM uses a separate set of roles for readonly/plan workflows, two sets of `providers.tf` files are generated: one for readonly and one for non-readonly. During plan pipeline runs, the non-readonly file should be removed. During apply pipeline runs, the readonly file should be removed. Don't remove the file manually, just run an `rm` command during the respective pipeline workflow.
