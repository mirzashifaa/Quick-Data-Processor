terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Cognito - user authentication and role-based access
# (Guest / Registered Customer / QDP Agent, per Sprint 2 report)
# ---------------------------------------------------------------------------

resource "aws_cognito_user_pool" "qdp_users" {
  name = "qdp-user-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  auto_verified_attributes = ["email"]

  lambda_config {
    post_confirmation = aws_lambda_function.post_confirmation.arn
  }
}

resource "aws_cognito_user_pool_client" "qdp_client" {
  name         = "qdp-frontend-client"
  user_pool_id = aws_cognito_user_pool.qdp_users.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}

# ---------------------------------------------------------------------------
# DynamoDB - Users and UserSecurityQuestions tables (per Sprint 2 report)
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "users" {
  name         = "Users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
  }
}

resource "aws_dynamodb_table" "user_security_questions" {
  name         = "UserSecurityQuestions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
  }
}

# ---------------------------------------------------------------------------
# SQS + SNS - data processing request queue and completion notifications
# (per resume: "Integrated AWS SQS/SNS for notifications")
# ---------------------------------------------------------------------------

resource "aws_sqs_queue" "data_processing_requests" {
  name                       = "qdp-data-processing-requests"
  visibility_timeout_seconds = 60
}

resource "aws_sns_topic" "processing_notifications" {
  name = "qdp-processing-notifications"
}

# ---------------------------------------------------------------------------
# IAM - shared execution role for Lambda functions
# ---------------------------------------------------------------------------

resource "aws_iam_role" "lambda_exec_role" {
  name = "qdp-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "qdp-lambda-exec-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          aws_dynamodb_table.user_security_questions.arn,
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
        ]
        Resource = aws_sqs_queue.data_processing_requests.arn
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.processing_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# Lambda functions - auth flows (register, login, generateQuestions, signout,
# postConfirmation), per Sprint 2 report module 1
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "register" {
  function_name = "qdp-auth-register"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "register.handler"
  runtime       = "nodejs18.x"
  filename      = "${path.module}/lambda_placeholder.zip"

  environment {
    variables = {
      USERS_TABLE                    = aws_dynamodb_table.users.name
      USER_SECURITY_QUESTIONS_TABLE  = aws_dynamodb_table.user_security_questions.name
      COGNITO_USER_POOL_ID           = aws_cognito_user_pool.qdp_users.id
    }
  }
}

resource "aws_lambda_function" "login" {
  function_name = "qdp-auth-login"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "login.handler"
  runtime       = "nodejs18.x"
  filename      = "${path.module}/lambda_placeholder.zip"

  environment {
    variables = {
      USERS_TABLE                    = aws_dynamodb_table.users.name
      USER_SECURITY_QUESTIONS_TABLE  = aws_dynamodb_table.user_security_questions.name
      COGNITO_USER_POOL_ID           = aws_cognito_user_pool.qdp_users.id
    }
  }
}

resource "aws_lambda_function" "generate_questions" {
  function_name = "qdp-auth-generate-questions"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "generateQuestions.handler"
  runtime       = "nodejs18.x"
  filename      = "${path.module}/lambda_placeholder.zip"
}

resource "aws_lambda_function" "post_confirmation" {
  function_name = "qdp-auth-post-confirmation"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "postConfirmation.handler"
  runtime       = "nodejs18.x"
  filename      = "${path.module}/lambda_placeholder.zip"

  environment {
    variables = {
      USERS_TABLE = aws_dynamodb_table.users.name
    }
  }
}

resource "aws_lambda_permission" "allow_cognito_invoke" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.qdp_users.arn
}

# ---------------------------------------------------------------------------
# API Gateway - REST API fronting the auth Lambda functions
# ---------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "qdp_api" {
  name = "qdp-api"
}
