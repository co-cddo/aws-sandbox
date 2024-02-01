terraform {
  backend "s3" {
    bucket = "cddo-sgs-sandbox-tfstate"
    key    = "infra/sandbox-access.tfstate"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      "Svc" : "sandbox-access",
      "Ref" : "https://github.com/co-cddo/aws-sandbox",
      "Env" : "sandbox"
    }
  }
}
