terraform {
  required_version = "~> 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  backend "local" {
    path = "./terraform.tfstate"
  }
}

# DynamoDB
resource "aws_dynamodb_table" "gang_of_straw" {
  name           = "gang_of_straw"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "name"
  range_key      = "bounty"
  attribute {
    name = "name"
    type = "S"
  }
  attribute {
    name = "bounty"
    type = "S"
  }
}

# IAM
resource "aws_iam_role" "dynamodb_read_only" {
  name = "dynamodb_read_only"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_log_writing_permit" {
  role       = aws_iam_role.dynamodb_read_only.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "dynamodb_reading_permit" {
  role       = aws_iam_role.dynamodb_read_only.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
}

# Lambda
data "archive_file" "lambda_function_file" {
  type        = "zip"
  source_dir  = "./src/"
  output_path = "./upload/lambda_function.zip"
}

resource "aws_lambda_function" "get_gang_info" {
  filename         = data.archive_file.lambda_function_file.output_path
  function_name    = "get_gang_info"
  role             = aws_iam_role.dynamodb_read_only.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_function_file.output_base64sha256
  runtime          = "python3.12"
  timeout          = 29
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.gang_of_straw.name
    }
  }
}

resource "aws_lambda_permission" "tr_lambda_permit" {
  statement_id  = "get_gang_info_api"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_gang_info.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.get_gang_info_api.execution_arn}/*/GET/gang"
}

# API Gateway
resource "aws_api_gateway_rest_api" "get_gang_info_api" {
  name = "get_gang_info_api"
}

resource "aws_api_gateway_resource" "gang_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.get_gang_info_api.id
  parent_id   = aws_api_gateway_rest_api.get_gang_info_api.root_resource_id
  path_part   = "gang"
}

resource "aws_api_gateway_method" "gang_get_method" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.gang_api_resource.id
  rest_api_id   = aws_api_gateway_rest_api.get_gang_info_api.id
}

resource "aws_api_gateway_integration" "get_gang_lambda_integration" {
  http_method             = aws_api_gateway_method.gang_get_method.http_method
  resource_id             = aws_api_gateway_resource.gang_api_resource.id
  rest_api_id             = aws_api_gateway_rest_api.get_gang_info_api.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_gang_info.invoke_arn
}

resource "aws_api_gateway_deployment" "tr_api" {
  depends_on = [
    aws_api_gateway_integration.get_gang_lambda_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.get_gang_info_api.id
  stage_name  = "dev"
  # triggers = {
  #   redeployment = filebase64("main.tf")
  # }
}
