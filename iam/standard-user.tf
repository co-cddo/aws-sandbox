resource "aws_iam_policy" "policy" {
  name        = "sandbox-user-base"
  policy = jsonencode(
    {
      Version   = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action = [
            "s3:*",
            "athena:*",
            "glue:*",
            "lambda:*",
            "bedrock:*",
            "cloudshell:*",
            "cloudwatch:*",
            "logs:*",
            "aws-marketplace:*",
            "kms:*",
            "ec2:*",
          ]
          Condition = {
            "ForAnyValue:StringLike" = {
              "aws:userid" = [
                "*:*@digital.cabinet-office.gov.uk",
              ]
            }
          }
          Resource = [
            "*",
          ]
          Sid = "AnyAccess"
        },
        {
          Action = "iam:PassRole"
          Condition = {
            StringLike = {
              "iam:PassedToService" = "glue.amazonaws.com"
            }
          }
          Effect   = "Allow"
          Resource = "arn:aws:iam::*:role/AWSGlueServiceRole*"
          Sid      = "PassRoleToGlue"
        },
        {
          Action = [
            "iam:PassRole",
          ]
          Condition = {
            StringEquals = {
              "iam:PassedToService" = [
                "bedrock.amazonaws.com",
              ]
            }
          }
          Effect   = "Allow"
          Resource = "arn:aws:iam::*:role/*AmazonBedrock*"
          Sid      = "PassRoleToBedrock"
        },
        {
          Action = [
            "iam:*",
          ]
          Effect = "Deny"
          Resource = [
            "arn:aws:iam::283416304068:role/*-admin",
            "arn:aws:iam::283416304068:role/aws-service-role/*",
            "arn:aws:iam::283416304068:role/GDSSecurityAudit",
            "arn:aws:iam::283416304068:role/TenableRole-CabinetOfficeDigital",
          ]
          Sid = "DenyAdminIAMAccess"
        },
        {
          Action = [
            "*",
          ]
          Condition = {
            "ForAllValues:StringEquals" = {
              "aws:TagKeys" = "Svc"
            }
            StringEquals = {
              "aws:ResourceTag/Svc" = "sandbox-access"
            }
          }
          Effect = "Deny"
          Resource = [
            "*",
          ]
          Sid = "DenySandboxAccess"
        },
      ]
    }
  )
}

variable "oidc_client_id" {
  type      = string
  sensitive = true
}

data "aws_iam_policy_document" "arp" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["accounts.google.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:aud"

      values = [
        var.oidc_client_id
      ]
    }
  }
}

resource "aws_iam_role" "user" {
  name                 = "co-cddo-sandbox-user"
  assume_role_policy   = data.aws_iam_policy_document.arp.json
  max_session_duration = 28800
}

resource "aws_iam_role_policy_attachment" "roa" {
  role       = aws_iam_role.user.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "bsa" {
  role       = aws_iam_role.user.name
  policy_arn = aws_iam_policy.policy.arn
}
