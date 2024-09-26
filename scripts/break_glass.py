import urllib
import json
import argparse
import requests
import boto3
from botocore.config import Config
from botocore.exceptions import NoCredentialsError, ClientError

# Script source: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_enable-console-custom-url.html#STSConsoleLink_programPython

# Default session and config
boto3_config = Config(retries={"mode": "standard", "max_attempts": 10})
default_session = (
    boto3.session.Session()
)  # This session will be used for default credentials
region = default_session.region_name

# STS client using the default credentials to assume a role
sts_connection = default_session.client("sts", config=boto3_config)

def send_email(email, recipient, url):
    """ """
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
      <p>This email was sent by Role Vending Machine per {recipient} request for break glass access.
        <br>
        <br>
        Please, follow the link below to access AWS console:
        <br>
      </p>
      <p>{url}</p>
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


def url_generator(arn, session_name):

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


def main():
    parser = argparse.ArgumentParser(
        description="Generate a console URL for a given role ARN."
    )
    parser.add_argument(
        "--role-arn", required=True, help="The ARN of the role to assume."
    )
    parser.add_argument(
        "--requester", required=True, help="The requester to use for the console URL."
    )
    parser.add_argument("--email", required=True, help="Email address of the requested")
    args = parser.parse_args()

    try:
        console_url = url_generator(
            arn=args.role_arn,
            session_name=args.requester,
        )
        send_email(email=args.email, recipient=args.requester, url=console_url)
    except Exception as e:
        # Add more context to the exception
        error_msg = f"An exception occurred while generating the console URL. Role ARN: {args.role_arn}, Requester: {args.requester}, Email: {args.email}"
        e.args = (error_msg,) + e.args
        raise


if __name__ == "__main__":
    main()
