# Role Vending Machine

Role Vending Machine (RVM) solution enables developers to get the right role permissions and trust policy, while reducing the undifferentiated heavy lifting of trust policy management and role creation. Security teams can audit (or require review on) the RVM repository to ensure that best practices for IAM roles are being met. The central nature of RVM also allows for the security team to include automated code scanning into the pipeline and enforce standards (ranging from naming conventions to permission boundaries). Out of the box, RVM offers [checkov](https://github.com/bridgecrewio/checkov) scanning for Terraform templates, and [IAM Access Analyzer policy validation](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-validation.html) using [IAM Policy Validator for Terraform](https://github.com/awslabs/terraform-iam-policy-validator).

RVM uses GitHub Actions to automate the role creation and deployment process. There are two main types of roles that you can create and manage using the Role Vending Machine:

- **Machine Roles**: These are roles that are intended to be used by AWS services or GitHub Actions to access resources on behalf of the service or application. They provide the necessary permissions for the service to perform its intended functions.
- **Break Glass Access Roles**: These are special roles that provide emergency or temporary access to AWS accounts, for example if your main IdP provider is experiencing an outage and you need console access to your AWS accounts.

## Machine roles

RVM allows developers to create roles for three different types of principals: GitHub pipelines, EKS pods, and other AWS services. Developers will commit Terraform files outlining required permissions and other essential details for their workload to RVM repository. When they create a pull request, a GitHub workflow initiates a Terraform plan to summarize the deployment changes, scans the Terraform template using Checkov, validates the submitted IAM policies against [IAM Access Analyzer policy check reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-reference-policy-checks.html), and adds this information to the pull request. Following a review and approval, and after merging the pull request, another workflow executes the Terraform apply command to deploy the proposed role in the target AWS account.

![RVM Workflow](assets/rvm-workflow.png)

## Break Glass Access Roles

Break glass access refers to a quick, emergency means for a person who does not normally have access privileges to certain AWS accounts to gain access in exceptional circumstances. This is done by using an approved process, similar to breaking the glass to trigger a fire alarm. The key use cases for break glass access include:

- Failure of the organization's identity provider (IdP)
- Security incidents involving the organization's IdP(s)
- Failures with IAM Identity Center
- Disasters resulting in the loss of the organization's cloud or identity management teams

![RVM Break Glass](assets/breakglass.png)

The Role Vending Machine takes a unique approach to managing break glass access, rather than creating dedicated break glass user accounts and roles in each AWS account. Instead, it:

- Creates a temporary role with the requested permissions when break glass access is needed, deploying it directly in the target account.
- Emails a console sign-in URL to the requester upon approval of the role creation. This URL is valid for only 15 minutes and does not require a username or password.

This approach has several advantages over traditional break glass methods:

1. Reduces the attack surface and operational overhead of managing break glass user and roles across all accounts.
2. Ensures the break glass role is provisioned with only the permissions approved by the security team, applying the principle of least privilege.
3. Provides a streamlined, secure way to grant emergency access without requiring user credentials.

> [!NOTE]
> The maximum console session time for these break glass roles is limited to 1 hour, due to role chaining limitations.
> view "Additional resources" section of [IAM Roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html#iam-term-role-chaining) on AWS documentations for more information.

> [!CAUTION]
> Be careful with this repository! RVM is inherently very powerful and you should add branch protection and PR reviews to ensure that unwanted changes are not made.
> Learn more about branch protection [here](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).

## Prerequisites

Before deploying RVM, ensure you meet the following prerequisites:

- A GitHub Organization (GitHub Enterprise/Premium/Ultimate are not required.)
- A multi-account AWS environment (does not need to be part of AWS Organizations)
- A mechanism for deploying an IAM role used by Role Vending Machine in all AWS accounts (e.g., AFT, StackSets)
- Terraform (v1.3+)
- AWS Terraform Provider (v4+)

## Getting started

### Step 1: Download or clone the repository

1. Begine by cloning this repository.
2. Remove remote references from your cloned repository.
3. Follow the guide [here](https://docs.github.com/en/get-started/getting-started-with-git/managing-remote-repositories#adding-a-remote-repository) to add your repository as a remote repository.
4. Follow the guide [here](https://docs.github.com/en/get-started/using-git/pushing-commits-to-a-remote-repository) to push the files to your organization repository.

### Step 2: Allow the Organization’s pipeline to create pull requests (PR)

This step is only necessary if you want to allow the *Generate Providers and Account Variables* workflow to create PRs. This workflow updates the Terraform providers file to include new AWS Organization’ account. View [Managing GitHub Actions settings for a repository](https://docs.github.com/en/enterprise-server@3.10/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository#preventing-github-actions-from-creating-or-approving-pull-requests) to learn how to allow or GitHub Actions workflows to creating pull requests.

*Note*: you can create the providers manually, and skip this step.

### Step 3: Designate an AWS account for Role Vending machine and delegate required permissions

Select or create an account in your AWS Organization to deploy RVM resources (for example, an `IamAdmin` account). If you plan to use *Generate Providers and Account Variables* workflow, you need to provide the RVM account with necessary permissions to list your organization's accounts. View [Delegated administrator for AWS Organizations](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_delegate_policies.html) for more information. Below is an example of the permissions required for the workflow to run properly:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowRvmRead",
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

Replace the `<YOUR RVM Account ID>` in the policy above with RVM's account ID.

### Step 4: Prepare the repository to Bootstrap the RVM repository

Provide necessary information to prepare the repository for bootstrapping. Below is a list of files you need to modify:

1. `.github/workflows/.env`: provide RVM account ID (for both `AWS_ACCOUNT_ID` and `TF_VAR_rvm_account_id` variables), AWS region, your GitHub organization name, and the level of IAM Access Analyzer finding that will break the pipeline. All other fields are optional to update.
2. `scripts/generate_providers_and_account_vars.py`: provide the main AWS region you operate in[^1].
3. Navigate to `bootstrap` folder under scripts folder.
   1. Update `terraform.tfvars` file with your GitHub organization name and the default AWS region where RVM resources are deployed into.
   2. Optionally, review the variables in `variables.tf` file and set your desired values in `terraform.tfvars` file. For example, if you want to deploy Terraform backend resources deployed in the RVM account, set the value of `create_tf_state_management_infrastructure` variable to `true`. If you want to use a repo name other than "role-vending-machine" (for example, if you use underscores instead of hyphens), you can set that in `terraform.tfvars` as well. If you are changing `breakglass_role_name` and `iam_role_name` default values, ensure you change the corresponding values in `.github/workflows/.env` as well.

[^1]: IAM resources are global, of course; the Region you specify in `generate_providers_and_account_vars.py` is used to create the AWS providers in each account, this can later be used with Terraform data structures to dynamically reference the Region in your policies.

### Step 5: Bootstrap the RVM repository

For RVM to operate properly you need to have certain resources deployed in your RVM account and the AWS accounts you are planning to create IAM roles using RVM:

- RVM main roles in RVM account[^2]
- An IAM OIDC provider in both RVM and target accounts[^3]
- A verified email and domain with [Amazon Simple Email Service](https://docs.aws.amazon.com/ses/latest/dg/Welcome.html) [^4]
- "Optional" Terraform backend resources (S3 bucket and DynamoDB table)

[^2]: RVM uses two main roles with different permissions. One with read only permissions used with `terraform plan` action, and one with write permissions used with `terraform apply` action to deploy roles into target accounts.

[^3]: IAM OIDC providers are used by GitHub workflows to assume roles in AWS accounts.

[^4]: To send emails from Amazon SES to your organization's email addresses, you must first [verify](https://docs.aws.amazon.com/ses/latest/dg/creating-identities.html) the domain you will be sending from by adding the necessary DNS records to your domain's configuration.

Figure below, shows the RVM bootstrapping process.

![RVM bootstrapping process](assets/boostrap.png)

1. Make sure you have local credentials set up to access the RVM account.
2. From terminal, navigate to `scripts/bootstrap` folder
   1. In the context of your RVM account, run `terraform init` to initiate Terraform.
   2. Run `terraform apply`, review the changes and approve to deploy RVM resources to RVM account. This will deploy IAM Main Role, and optionally Terraform backend resources.
3. Set up your SES account
   1. Sign in to the AWS Management Console and open the Amazon SES console at [https://console.aws.amazon.com/ses/](https://console.aws.amazon.com/ses/).
   2. Select Get started from the SES console home page and the wizard will walk you through the steps of setting up your SES account.
  
### Step 6: Deploying RVM-assumable roles across the AWS Organization

1. Using a method such as AFT or StackSets, deploy the RVM Workflow Role and create an IAM OIDC provider in each account where you expect RVM to deploy roles. You can find Terraform definitions for both of these resources in `scripts/assumed_role` and `scripts/oidc_provider` folders.
2. Note that this step includes provisioning the IAM OIDC provider to the RVM account. Subsequent steps will not be possible without the OIDC setup.

### Step 7: RVM variables and backend setup

1. Update `role_vending_machine/zz-do-not-modify-backend.tf` file with RVM Terraform backend information (note: the "do not modify" directive is aimed at developers using this repository; RVM administrators may modify these manifests).
2. Commit the result.
3. From your repository’s main page, click on Actions, under All Workflows sections, click on *Generate Providers and Account Variables workflow*, and run the workflow. This will create the Terraform providers file in your repository.

### Step 8 (optional): Fine tuning RVM

With RVM, you can create IAM roles to be assumed by GitHub pipelines or AWS services with additional configurability for EKS Pod Identity roles. There are two local variables in RVM module's [main.tf](github-workflow-roles/main.tf) file allowing you to include additional conditions in the trust policy of the roles created for AWS services:

- `service_trust_policy_controls` for general AWS service roles
- `pod_trust_policy_controls` for EKS Pod Identity roles

sections below lists the variables and the condition they to role's trust policy when set true. All of the variables are of Boolean type. Click on each variable to view the condition associated with it.

#### `service_trust_policy_controls` variables

<details>

<summary>include_account_condition</summary>

```json
"Condition": {
    "StringEquals": {
        "aws:SourceAccount": <Account ID of target account>
    }
}
```

</details>

<details>

<summary>include_org_condition</summary>

```json
"Condition": {
    "StringEquals": {
        "aws:SourceOrgID": "${aws:ResourceOrgId}"
    }
}
```

</details>

#### `pod_trust_policy_controls` variables

<details>

<summary>include_source_account</summary>

```json
"Condition": {
    "StringEquals": {
        "aws:SourceAccount": <Account ID of target account>
    }
}
```

</details>

<details>

<summary>include_cluster_arns</summary>

```json
"Condition": {
    "ArnEquals": {
        "aws:SourceArn": [
            <EKS_ARN1>,
            <EKS_ARN2>
        ]
    }
}
```

</details>

<details>

<summary>include_cluster_names</summary>

```json
"Condition": {
    "StringEquals": {
        "aws:PrincipalTag/eks-cluster-name": [
            <my-cluster-1>,
            <my-cluster-2>
        ]
    }
}
```

</details>

<details>

<summary>include_cluster_namspaces</summary>

```json
"Condition": {
    "StringEquals": {
        "aws:PrincipalTag/kubernetes-namespace": [
            <namespace-1>,
            <namespace-2>
        ]
    }
}
```

</details>

<details>

<summary>include_cluster_service_account</summary>

```json
"Condition": {
    "StringEquals": {
        "aws:PrincipalTag/kubernetes-service-account": [
            <service-account-1>,
            <service-account-2>
        ]
    }
}
```

</details></br>

> [!TIP]
> EKS Pod Identity role trust conditions will be added only if the developers include these values in their role definition Terraform file. If you want to enforce inclusion of these variables, you can remove the default value of `eks_cluster_arns`, `eks_cluster_name`, `eks_namespaces`, and `eks_service_account` variables in `github-workflow-roles/variables.tf` file.

## Role Vending Workflow

Developers should push a Terraform definition file to the role_vending_machine subfolder. The definition file includes a module from the *github-workflow-roles* module as its source. They also add details related to the role including the specific role permissions they need.

### Adding a role

To start, create a feature branch in your local environment. Next, create a Terraform file in [`role-vending-machine`](./role-vending-machine) folder, [define a module](https://developer.hashicorp.com/terraform/language/modules/develop) with a meaningful name and specify [`github-workflow-roles`](./github-workflow-roles/) as the source of the module. You also need to provide values for some the variables defined in `github-workflow-roles` [`variables.tf`](./github-workflow-roles/variables.tf) file. The following section lists the variables that you can provide for each role type. Click on each role type to learn more about the variables.

<details>

<summary>GitHub pipeline roles</summary>

| Variable | Description |
|----------|----------|
| principal_type | For GitHub pipeline roles this value should be set to `github` |
| provider | Indicates the target account to deploy the role. Review the `zz-do-not-modify-providers.tf` file in role-vending-machine folder for a list of available providers. |
| repository_nam | Repository name in GitHub which is expected to consume the role. |
| github_branc | The protected GitHub branch (eg. main) that is allowed to assume the read-write IAM role. |
| inline_polic | Points out to the aws_iam_policy_document containing the permissions requested. |
| github_environment | [Optional] if you use GitHub environments, you can specify the environment name to be added to as a subscriber of OIDC in role trust policy. |

</details>

<details>

<summary>EKS pod roles</summary>

| Variable | Description |
|----------|----------|
| principal_type | For EKS pod roles this value should be set to `pod` |
| providers | Indicates the target account to deploy the role. Review the `zz-do-not-modify-providers.tf` file in role-vending-machine folder for a list of available providers. |
| role_name | The name of the role after creation. |
| eks_cluster_names | [Optional] A list of EKS cluster names whose pods can assume the role. |
| eks_namespaces | [Optional] A list of EKS cluster namespaces where pods in those namespaces can assume the role. |
| eks_service_accounts | [Optional] A list of EKS service accounts that allow pods using those service accounts to assume the role. |
| eks_cluster_arns | [Optional] A list of EKS cluster ARNs whose pods can assume the role. |

> [!NOTE]
> The owner of the github-workflow-roles module (for example, the security team) determines if the values for eks_cluster_names, eks_namespaces, and eks_service_accounts are used to refine the role trust policy.

</details>

<details>

<summary>AWS service roles</summary>

| Variable | Description |
|----------|----------|
| principal_type | For AWS service roles this value should be set to `service` |
| providers | Indicates the target account to deploy the role. Review the `zz-do-not-modify-providers.tf` file in role-vending-machine folder for a list of available providers. |
| role_name | The name of the role after creation. |
| service_name | A list of AWS services that can assume the role. We recommend not to include more than one service type. |
| service_arn | The ARN of the service assuming the role. |

> [!NOTE]
> The service’s ARN might not be available when you’re creating the role, requiring you to create the role before the resource. In this situation, refer to the [Service Authorization Reference](https://docs.aws.amazon.com/service-authorization/latest/reference/reference.html) to determine the resource’s ARN format and use it with the service_arn variable.

</details>

<details>

<summary>Break Glass roles</summary>

| Variable | Description |
|----------|----------|
| principal_type | For break glass roles this value should be set to `breakglass` |
| providers | Indicates the target account to deploy the role. Review the `zz-do-not-modify-providers.tf` file in role-vending-machine folder for a list of available providers. |
| role_name | The name of the role after creation. |
| breakglass_user_alias | Alias of the user requesting break glass access. |
| breakglass_user_email | Email of the user requesting break glass access. |

> [!NOTE]
> To prevent regenerating and resending the console URL after each Terraform apply, the GitHub workflow checks the `create_date` tag of the break glass roles. It only processes roles that have been created within the past 3 minutes. This ensures the console URLs are not repeatedly generated and sent unnecessarily.

</details>

</br>After creating the module block and specifying all the required variables, create a Terraform `aws_iam_policy_document` data block and include the permissions for your role. Following is an example of a Terraform manifest you can create for a GitHub pipeline role.

```hcl
module "example_security_inf_repo_Production" {
  source                   = "../github-workflow-roles"
  github_organization_name = var.default_github_organization_name

  # Specify target account
  providers = {
    aws = aws.Production
  }

  # Trusted GitHub repository
  repository_name = "example-security-inf-repo"

  # Trusted branch for write operations
  github_branch = "main"

  # Specify the least permissions required for this pipeline to run
  inline_policy = data.aws_iam_policy_document.example_security_inf_repo_Production_permissions.json
}

data "aws_iam_policy_document" "example_security_inf_repo_Production_permissions" {
  # Can include multiple statements
  statement {
    sid    = "SQSQueues"
    effect = "Allow"
    actions = [
      "sqs:CreateQueue",
      "sqs:DeleteQueue",
      "sqs:TagQueue",
      "sqs:UntagQueue",
      "sqs:SetQueueAttributes"
    ]
    # Reference account numbers using the `variables-accounts` file
    resources = ["arn:aws:sqs:*:${var.account_Production}:aws-s3-access-logs"]
  }
}
```

Finally, add, Commit, and PR your changes to the `main` branch.

### Updating a role

To update the role, make changes to the Terraform manifest containing the role definion, and add, Commit, and PR your changes to the `main` branch.

### Pull Request Review Process

Reviewers - Your work is crucial to maintaining a high level of code quality. Please consider the following while reviewing Pull Requests:

- New Terraform role file names match the repository name
- Terraform module identifiers are unique and specific to the repository
- Correct provider names are used for the repository
- Role policies do not contain hardcoded account numbers, and instead reference account IDs by the pre-generated variables
- Role policies are least-permissive
- Role policies do not contain wildcards `*` on principals
- Role policies do not authorize principals outside of this AWS Organization

## Auto-magical `providers.tf` and `variables-accounts-<env>.tf`

To save toil and prevent human error while modifying the `providers.tf` Terraform file to include both a terraform provider definition and a terraform variable for each account.

How it works:

- A GitHub workflow called `Generate Providers and Account Variables` runs on a daily schedule
- The script at `scripts\generate_providers_and_account_vars.py` consumes JSON formatted account lists
- Provider definitions and terraform variables files are generated and an automatic PR is cut if these files need to be updated.
- Because RVM uses a separate set of roles for readonly/plan workflows, two sets of `providers.tf` files are generated: one for readonly and one for non-readonly. During plan pipeline runs, the non-readonly file should be removed. During apply pipeline runs, the readonly file should be removed. Don't remove the file manually, just run an `rm` command during the respective pipeline workflow.
