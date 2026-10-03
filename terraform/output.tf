# Lambda function execution role arn
output "lambda_function_execution_role_arn" {
  value = aws_iam_role.lambda_execution_role.arn
}

# Lambda function cloudwatch log group
output "lambda_function_cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.lambda_log_group.name
}

# Lambda function security group id
output "lambda_function_security_group_id" {
  value = aws_security_group.lambda_function_sg.id
}

# Lambda function arn
output "lambda_function_arn" {
  value = aws_lambda_function.lambda_function.arn
}