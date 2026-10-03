## cloudwatch log group
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.cloudwatch_log_retention_in_days
  tags = merge(var.tags, {
    "Name" = "/aws/lambda/${var.lambda_function_name}"
  })
}

## IAM role and least-privilege execution policy
data "aws_caller_identity" "current" {}

locals {
  # Extract repository name from image URI
  # Format: account_id.dkr.ecr.region.amazonaws.com/repository_name:tag

  image_uri_parts    = split("/", var.image_uri)
  repository_name    = split(":", local.image_uri_parts[1])[0]
  ecr_registry_parts = split(".", local.image_uri_parts[0])
  ecr_region         = local.ecr_registry_parts[3]
  ecr_repository_arn = "arn:aws:ecr:${local.ecr_region}:${data.aws_caller_identity.current.account_id}:repository/${local.repository_name}"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_execution" {
  statement {
    sid       = "WriteFunctionLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.lambda_log_group.arn}:*"]
  }

  statement {
    sid    = "ManageLambdaVpcNetworkInterfaces"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "GetEcrAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PullFunctionImage"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [local.ecr_repository_arn]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_policy" "lambda_execution_policy" {
  policy = data.aws_iam_policy_document.lambda_execution.json
  name   = "${var.lambda_function_name}-execution"
  tags = merge(var.tags, {
    "Name" = "${var.lambda_function_name}-execution"
  })
}

resource "aws_iam_role" "lambda_execution_role" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  name               = var.lambda_function_name
  tags = merge(var.tags, {
    "Name" = var.lambda_function_name
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution" {
  policy_arn = aws_iam_policy.lambda_execution_policy.arn
  role       = aws_iam_role.lambda_execution_role.name
}
### Lambda Security Group
resource "aws_security_group" "lambda_function_sg" {
  name        = "${var.lambda_function_name}-sg"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id
  tags = merge(var.tags, {
    "Name" = "${var.lambda_function_name}-sg"
  })
}

resource "aws_vpc_security_group_egress_rule" "lambda_https_egress" {
  security_group_id = aws_security_group.lambda_function_sg.id
  description       = "Allow HTTPS egress for AWS API access"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

### KMS key for lambda function
resource "aws_kms_key" "lambda_kms_key" {
  description             = "KMS key for Lambda function ${var.lambda_function_name}"
  enable_key_rotation     = var.enable_key_rotation
  rotation_period_in_days = var.rotation_period_in_days
  is_enabled              = true
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = var.deletion_window_in_days
  tags = merge(var.tags, {
    "Name" = "${var.lambda_function_name}-kms"
  })
}

resource "aws_kms_alias" "lambda_kms_alias" {
  target_key_id = aws_kms_key.lambda_kms_key.arn
  name          = "alias/${var.lambda_function_name}"
}

### Lambda function
resource "aws_lambda_function" "lambda_function" {
  function_name = var.lambda_function_name
  description   = "Lambda function for ${var.lambda_function_name}"
  role          = aws_iam_role.lambda_execution_role.arn
  package_type  = "Image"
  image_uri     = var.image_uri
  dynamic "image_config" {
    for_each = length(var.entry_point) > 0 || length(var.command) > 0 ? [true] : []
    content {
      entry_point = var.entry_point
      command     = var.command
    }
  }
  memory_size   = var.memory_size
  timeout       = var.timeout
  architectures = var.architectures
  vpc_config {
    security_group_ids = [aws_security_group.lambda_function_sg.id]
    subnet_ids         = var.private_subnet_ids
  }
  logging_config {
    log_format            = "JSON"
    log_group             = aws_cloudwatch_log_group.lambda_log_group.name
    system_log_level      = "WARN"
    application_log_level = "ERROR"
  }
  environment {
    variables = var.variables
  }
  kms_key_arn = aws_kms_key.lambda_kms_key.arn
  tags = merge(var.tags, {
    "Name" = var.lambda_function_name
  })
}
