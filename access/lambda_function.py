import boto3
import json
import requests
import os
import urllib.parse

from base64 import b64decode

AWS_REGION = os.getenv("AWS_REGION")
AWS_ROLE_DURATION = 28800
SSO_CLIENT_ID = os.getenv("SSO_CLIENT_ID")
SSO_CLIENT_SECRET = os.getenv("SSO_CLIENT_SECRET")


def aws_console_signin(credentials: dict):
    session_data = {
        "sessionId": credentials["AccessKeyId"],
        "sessionKey": credentials["SecretAccessKey"],
        "sessionToken": credentials["SessionToken"],
    }
    aws_federated_signin_endpoint = "https://signin.aws.amazon.com/federation"

    response = requests.get(
        aws_federated_signin_endpoint,
        params={
            "Action": "getSigninToken",
            "SessionDuration": AWS_ROLE_DURATION - 1,
            "Session": json.dumps(session_data),
        },
    )

    query_string = urllib.parse.urlencode(
        {
            "Action": "login",
            "Issuer": SSO_CLIENT_ID,
            "Destination": f"https://{AWS_REGION}.console.aws.amazon.com/console/home",
            "region": AWS_REGION,
            "SigninToken": response.json()["SigninToken"],
        }
    )
    federated_url = f"{aws_federated_signin_endpoint}?{query_string}"

    return {
        "statusCode": 302,
        "statusDescription": "Found",
        "isBase64Encoded": False,
        "headers": {"Location": federated_url},
        "body": federated_url,
    }


def ret401():
    return {
        "statusCode": 401,
        "statusDescription": "Unauthorised",
        "isBase64Encoded": False,
        "headers": {"Content-Type": "text/html"},
        "body": "Unauthorised",
    }


def lambda_handler(event, context):
    print(json.dumps(event, default=str))

    raw_oidc_data = event["headers"]["x-amzn-oidc-data"]
    oidc_data = json.loads(b64decode(raw_oidc_data.split(".")[1].encode()))
    email = oidc_data["email"]

    if not email.endswith("@digital.cabinet-office.gov.uk"):
        return ret401()

    access_token = event["headers"]["x-amzn-oidc-accesstoken"]
    token_url = "https://oauth2.googleapis.com/token"
    auth_token_params = {
        "client_id": SSO_CLIENT_ID,
        "client_secret": SSO_CLIENT_SECRET,
        "refresh_token": access_token,
        "grant_type": "refresh_token",
    }
    google_response = requests.post(token_url, data=auth_token_params)
    if google_response.status_code != 200:
        print(f"assume_role: {token_url} failed: {google_response.status_code}")
        return ret401()

    client = boto3.client("sts")
    assumed_role = client.assume_role_with_web_identity(
        RoleArn="arn:aws:iam::283416304068:role/co-cddo-sandbox-user",
        RoleSessionName=oidc_data["email"],
        WebIdentityToken=google_response.json()["id_token"],
        DurationSeconds=AWS_ROLE_DURATION - 1,
    )

    if "Credentials" in assumed_role:
        return aws_console_signin(assumed_role["Credentials"])

    return ret401()
