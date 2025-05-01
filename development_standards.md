## Role Vending Workflow

### Adding a role

In a new branch, developers should add a Terraform manifest file (typically named `<repo_name>-<account_name>.tf`) to the `role-vending-machine` subfolder. The definition file includes a module from the *github-workflow-roles* module as its source. They also add details related to the role including the specific role permissions they need.

You will need to provide values for some the variables defined in `github-workflow-roles` [`variables.tf`](./github-workflow-roles/variables.tf) module. The following section lists the variables that you can provide for each role type. Click on each role type to learn more about the variables.

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

</br>

After creating the module block and specifying all the required variables, create a Terraform `aws_iam_policy_document` data block and include the permissions for your role. Following is an example of a Terraform manifest you can create for a GitHub pipeline role.

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

Finally, add, commit, and PR your changes to the `main` branch.

### Updating a role

To update the role, make changes to the Terraform manifest containing the role definion, and add, commit, and (with approval) merge your changes to the `main` branch.

### Pull Request Review Process

Reviewers - Your work is crucial to maintaining a high level of code quality. Please consider the following while reviewing Pull Requests:

- New Terraform role file names match the repository name
- Terraform module identifiers are unique and specific to the repository
- Correct provider names are used for the repository
- Role policies do not contain hardcoded account numbers, and instead reference account IDs by the pre-generated variables
- Role policies are least-permissive
- Role policies do not contain wildcards `*` on principals
- Role policies do not authorize principals outside of this AWS Organization
