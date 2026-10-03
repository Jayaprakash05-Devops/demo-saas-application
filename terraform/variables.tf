variable "lambda_function_name" {
  type        = string
  description = "Name of the Lambda function and its supporting resources."

  validation {
    condition     = length(var.lambda_function_name) > 0 && length(var.lambda_function_name) <= 64
    error_message = "lambda_function_name must contain between 1 and 64 characters."
  }
}

variable "image_uri" {
  type        = string
  description = "ECR image URI containing the Lambda function deployment package."

  validation {
    condition     = length(trimspace(var.image_uri)) > 0
    error_message = "image_uri must be a non-empty container image URI."
  }
}

variable "entry_point" {
  type        = list(string)
  default     = []
  description = "Optional container entry point override."
}

variable "command" {
  type        = list(string)
  default     = []
  description = "Optional container command override."
}

variable "variables" {
  type        = map(string)
  default     = {}
  description = "Environment variables for the Lambda function. Do not put secrets here."
}

variable "memory_size" {
  type        = number
  default     = 128
  description = "Amount of memory in MB available to the function (128-10240)."

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240 && floor(var.memory_size) == var.memory_size
    error_message = "memory_size must be a whole number between 128 and 10240 MB."
  }
}

variable "timeout" {
  type        = number
  default     = 3
  description = "Maximum function execution time in seconds (1-900)."

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900 && floor(var.timeout) == var.timeout
    error_message = "timeout must be a whole number between 1 and 900 seconds."
  }
}

variable "architectures" {
  type        = list(string)
  default     = ["x86_64"]
  description = "Single Lambda instruction-set architecture: x86_64 or arm64."

  validation {
    condition     = length(var.architectures) == 1 && contains(["x86_64", "arm64"], var.architectures[0])
    error_message = "architectures must contain exactly one value: x86_64 or arm64."
  }
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "IDs of private subnets in which to place the Lambda function. Supply subnets with no direct route to an internet gateway."

  validation {
    condition     = length(var.private_subnet_ids) > 0 && length(toset(var.private_subnet_ids)) == length(var.private_subnet_ids)
    error_message = "Provide one or more unique private subnet IDs."
  }
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC containing the private subnets."

  validation {
    condition     = length(trimspace(var.vpc_id)) > 0
    error_message = "vpc_id must be a non-empty VPC ID."
  }
}

variable "cloudwatch_log_retention_in_days" {
  type        = number
  default     = 7
  description = "CloudWatch log retention period in days."

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90], var.cloudwatch_log_retention_in_days)
    error_message = "cloudwatch_log_retention_in_days must be a supported CloudWatch Logs retention value."
  }
}

variable "enable_key_rotation" {
  type        = bool
  default     = true
  description = "Whether automatic KMS key rotation is enabled."
}

variable "rotation_period_in_days" {
  type        = number
  default     = 365
  description = "KMS key rotation period in days (90-2560)."

  validation {
    condition     = var.rotation_period_in_days >= 90 && var.rotation_period_in_days <= 2560
    error_message = "rotation_period_in_days must be between 90 and 2560."
  }
}

variable "deletion_window_in_days" {
  type        = number
  default     = 10
  description = "Waiting period before KMS deletes the key (7-30 days)."

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "tags" {
  type = object({
    Environment = string
    Owner       = string
    Project     = string
    Team        = string
    Contact     = string
    CostCenter  = string
  })
}