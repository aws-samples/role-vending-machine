import boto3
import os


def apply_proto_rvm(
    rvm_role_name="github-workflow-rvm",
):
    """
    This function will assume the RVM role and use it to apply the latest version of RVM.
    """

    # Check out the main branch using git
    os.system("git checkout main")

    # Do a git pull
    os.system("git pull")

    # Assume the RVM role
    sts_client = boto3.client("sts")
    assumed_role_object = sts_client.assume_role(
        RoleArn=f"arn:aws:iam::{boto3.client('sts').get_caller_identity()['Account']}:role/{rvm_role_name}",
        RoleSessionName="AssumeRoleSession1",
    )
    # Set environment variables -- note: this will overwrite your existing CLI credentials
    credentials = assumed_role_object["Credentials"]
    os.environ["AWS_ACCESS_KEY_ID"] = credentials["AccessKeyId"]
    os.environ["AWS_SECRET_ACCESS_KEY"] = credentials["SecretAccessKey"]
    os.environ["AWS_SESSION_TOKEN"] = credentials["SessionToken"]

    # Run terraform apply from the role-vending-machine directory
    os.chdir("role-vending-machine")
    os.system(f"terraform apply -auto-approve")


if __name__ == "__main__":
    apply_proto_rvm()
