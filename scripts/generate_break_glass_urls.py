import argparse
import datetime
import json
import urllib
import json
import logging
import requests
import boto3
from botocore.config import Config
from botocore.exceptions import NoCredentialsError, ClientError

# Script inspired by: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_enable-console-custom-url.html#STSConsoleLink_programPython

logging.basicConfig(level=logging.INFO)


def extract_break_glass_roles(
    tf_state_path: str = "./state.json",
):
    """
    Takes a path to a Terraform state file and extracts all roles with the tag "principal_type=breakglass" and created within the last 3 minutes.
    Output: Returns an object with the extracted roles
    """
    current_timestamp = datetime.datetime.now().timestamp()
    breakglass_roles = []
    with open(tf_state_path, "r") as f:
        state_data = json.load(f)
        logging.debug(state_data)
        child_modules = (
            state_data.get("values", {}).get("root_module", {}).get("child_modules", [])
        )
        for child_module in child_modules:
            resources = child_module.get("resources", [])
            logging.warning(resources)
            # Filter roles with principal_type="breakglass" and created within the last 3 minutes
            for resource in resources:
                if (
                    resource.get("type") == "aws_iam_role"
                    and resource.get("values", {}).get("tags", {}).get("principal_type")
                    == "breakglass"
                ):
                    create_date = (
                        resource.get("values", {}).get("tags", {}).get("create_date")
                    )
                    if create_date:
                        create_date_timestamp = datetime.datetime.strptime(
                            create_date, "%Y-%m-%dT%H:%M:%SZ"
                        ).timestamp()
                        logging.warning(f"Create timestamp: {create_date_timestamp}")
                        logging.warning(f"Current timestamp: {current_timestamp}")
                        if (
                            current_timestamp - create_date_timestamp <= 180
                        ):  # 3 minutes in seconds
                            breakglass_roles.append(resource.get("values"))
                        else:
                            logging.warning(
                                f"Role {resource.get('name')} is older than 3 minutes"
                            )
    num_roles = len(breakglass_roles)
    logging.info(f"Found {num_roles} roles to process")
    return breakglass_roles


def generate_break_glass_urls(input_roles: list[dict]):
    """
    Takes a JSON file of breakglass roles and generates a breakglass URL for each role.
    Output: Prints a breakglass URL for each role
    """
    for role in input_roles:
        role_arn = role.get("arn")
        requester = role.get("tags", {}).get("requester")
        email = role.get("tags", {}).get("email")
        print(f"Running breakglass script for role: {role_arn}")
        url_generator_wrapper(
            role_arn=role_arn,
            requester=requester,
            email=email,
        )


def send_email(
    email,
    recipient,
    url,
    default_session,
    region,
):
    """
    Sends the email containing the login URL
    """

    SENDER = email  # Replace with your verified email address
    RECIPIENT = email  # Replace with the recipient email address
    SUBJECT = "Sensitive: Break Glass access"
    BODY_TEXT = (
        f"This email was sent by RVM per {recipient} request for break glass access."
    )
    BODY_HTML = f"""<html>
    <head></head>
    <body>
      <h1>Hello!</h1>
      <h2>DO NOT FORWARD THIS EMAIL. IT CONTAINS AN AWS SIGN-IN TOKEN.</h2>
      <p>This email was sent by Role Vending Machine per {recipient}'s request for break glass access.
        <br>
        <br>
        Please, follow the link below to access AWS console:
        <br>
      </p>
      <p>{url}</p>
      <br>
      <br>
    </body>
    </html>"""

    CHARSET = "UTF-8"

    ses_client = default_session.client("ses", region_name=region)

    # Try to send the email.
    try:
        # Provide the contents of the email.
        response = ses_client.send_email(
            Destination={"ToAddresses": [RECIPIENT]},
            Message={
                "Body": {
                    "Html": {"Charset": CHARSET, "Data": BODY_HTML},
                    "Text": {"Charset": CHARSET, "Data": BODY_TEXT},
                },
                "Subject": {"Charset": CHARSET, "Data": SUBJECT},
            },
            Source=SENDER,
        )
    except ClientError as e:
        print(f"Error: {e.response['Error']['Message']}")
    except NoCredentialsError:
        print("Credentials not available.")
    else:
        print("Email sent! Message ID:"),
        print(response["MessageId"])


def url_generator(arn, session_name, sts_connection):

    assumed_role_object = sts_connection.assume_role(
        RoleArn=arn,
        RoleSessionName=session_name + "breakGlass",
    )

    # Format resulting temporary credentials into JSON
    url_credentials = {}
    url_credentials["sessionId"] = assumed_role_object.get("Credentials").get(
        "AccessKeyId"
    )
    url_credentials["sessionKey"] = assumed_role_object.get("Credentials").get(
        "SecretAccessKey"
    )
    url_credentials["sessionToken"] = assumed_role_object.get("Credentials").get(
        "SessionToken"
    )
    json_string_with_temp_credentials = json.dumps(url_credentials)

    # Make request to AWS federation endpoint to get sign-in token. Construct the parameter string with
    # the sign-in action request, a 12-hour session duration, and the JSON document with temporary credentials
    # as parameters.
    request_parameters = "?Action=getSigninToken"
    request_parameters += "&Session=" + urllib.parse.quote_plus(
        json_string_with_temp_credentials
    )
    request_url = "https://signin.aws.amazon.com/federation" + request_parameters
    r = requests.get(request_url)
    signin_token = json.loads(r.text)

    request_parameters = "?Action=login"
    request_parameters += "&Issuer=Example.org"
    request_parameters += "&Destination=" + urllib.parse.quote_plus(
        "https://console.aws.amazon.com/"
    )
    request_parameters += "&SigninToken=" + signin_token["SigninToken"]
    request_url = "https://signin.aws.amazon.com/federation" + request_parameters

    return request_url


def url_generator_wrapper(role_arn, requester, email):
    # Default session and config
    boto3_config = Config(retries={"mode": "standard", "max_attempts": 10})
    default_session = (
        boto3.session.Session()
    )  # This session will be used for default credentials
    region = default_session.region_name
    # STS client using the default credentials to assume a role
    sts_connection = default_session.client("sts", config=boto3_config)
    try:
        console_url = url_generator(
            arn=role_arn,
            session_name=requester,
            sts_connection=sts_connection,
        )
        send_email(
            email=email,
            recipient=requester,
            url=console_url,
            default_session=default_session,
            region=region,
        )
    except Exception as e:
        # Add more context to the exception
        error_msg = f"An exception occurred while generating the console URL. Role ARN: {role_arn}, Requester: {requester}, Email: {email}"
        e.args = (error_msg,) + e.args
        raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate a console URL for a given role ARN."
    )
    parser.add_argument(
        "--tf-state-path",
        default="./state.json",
        help="Path to the Terraform state file.",
    )
    args = parser.parse_args()
    extracted_roles = extract_break_glass_roles(tf_state_path=args.tf_state_path)
    generate_break_glass_urls(input_roles=extracted_roles)