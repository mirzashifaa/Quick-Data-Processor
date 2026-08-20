# Terraform - AWS Backend Infrastructure

Provisions the AWS-side infrastructure for QDP's authentication and data
processing flow:

- **Cognito** — user pool + client for sign-up/login, with a post-confirmation
  Lambda trigger
- **DynamoDB** — `Users` and `UserSecurityQuestions` tables
- **Lambda** — auth flow functions (register, login, generateQuestions,
  postConfirmation)
- **SQS** — queue for incoming data processing requests
- **SNS** — topic for notifying users once processing completes
- **API Gateway** — REST API shell fronting the auth Lambdas
- **IAM** — a scoped execution role for the Lambda functions, limited to the
  DynamoDB tables, SQS queue, and SNS topic above

## Status

The Lambda function resources currently point at `lambda_placeholder.zip`, a
stub handler — this defines the infrastructure shape, but the real function
code (register/login/generateQuestions logic) isn't packaged here yet. Replace
`lambda_placeholder.zip` with a real deployment package, or point each
`filename` at the actual built Lambda source, before applying this against a
live account.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

State is local (`terraform.tfstate`) by default — for multi-person or CI use,
configure a remote backend (e.g. an S3 bucket) instead.
