/*

provider "aws" {
     region = "eu-north-1"
  }

  resource "aws_iam_role" "lambda_role" {
     name = "thomasmajnie@gmail.com"
     assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
           Action = "sts:AssumeRole",
           Effect = "Allow",
           Principal = {
           Service = "lambda.amazonaws.com"
           }
        }]
     })
  }

  resource "aws_lambda_function" "backend" {
     filename         = "backend.zip"
     function_name    = "ThomasNielsenTerraform"
     role             = aws_iam_role.lambda_role.arn
     handler          = "Backend::Backend.Function::FunctionHandler"
     runtime          = "java" -- JAVAENVIRONMENT
     source_code_hash = filebase64sha256("backend.zip")
  }

  resource "aws_api_gateway_rest_api" "api" {
     name = "ThomasNAPI"
  }

  resource "aws_api_gateway_resource" "resource" {
     rest_api_id = aws_api_gateway_rest_api.api.id
     parent_id   = aws_api_gateway_rest_api.api.root_resource_id
     path_part   = "register"
  }

  resource "aws_api_gateway_method" "method" {
     rest_api_id   = aws_api_gateway_rest_api.api.id
     resource_id   = aws_api_gateway_resource.resource.id
     http_method   = "GET"
     authorization = "NONE"
  }

  resource "aws_api_gateway_integration" "integration" {
     rest_api_id = aws_api_gateway_rest_api.api.id
     resource_id = aws_api_gateway_resource.resource.id
     http_method = aws_api_gateway_method.method.http_method
     type        = "AWS_PROXY"
     integration_http_method = "POST"
     uri         = aws_lambda_function.backend.invoke_arn
  }
  */
provider "aws" {
  region = "eu-west-1"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda_role" {
  name = "thomasmajnie@gmail.com"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:eu-west-1:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*/*"
}

resource "aws_lambda_function" "backend" {
  s3_bucket        = "thomas-nielsen-test-bucket"
  s3_key           = "backend.zip"
  function_name    = "thomas-nielsen-terraform"
  role             = aws_iam_role.lambda_role.arn
  handler          = "com.booleanuk.StreamLambdaHandler::handleRequest"
  runtime          = "java21"
  memory_size      = 512
  timeout          = 120
}

resource "aws_api_gateway_rest_api" "api" {
  name = "thomas-nielsen-api"
}

resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "todos"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.backend.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [aws_api_gateway_integration.integration]
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}

output "api_url" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}