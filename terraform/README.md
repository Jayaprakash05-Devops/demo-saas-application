# AWS Lambda Container Image Module

Creates an image-based AWS Lambda function, its execution role, a CloudWatch log
group, a customer-managed KMS key, and a dedicated VPC security group.

The Lambda function is always configured with `package_type = "Image"` and must
be attached to one or more **private subnets**. Pass subnet IDs whose route
tables do not have a direct route to an internet gateway. This module requires
at least one private subnet; using private subnets in multiple Availability
Zones is recommended for availability.

The security group has no ingress rules. Its only egress rule allows TCP port
443 to `0.0.0.0/0`. This limits outbound ports but still permits HTTPS traffic
to any IPv4 destination. To restrict egress to AWS services, replace this
destination with the appropriate VPC endpoint or prefix-list destinations;
adding additional rules will not narrow this existing rule.

## Usage

Configure the AWS provider in the calling root module. Both examples below
assume this provider configuration:

```hcl
provider "aws" {
  region = "us-east-1"
}
```

### Required variables only

```hcl
module "lambda_function" {
  source = "git::https://github.com/jayaprakashvishnu/terraform-aws-lambda.git?ref=v1.0.0"

  lambda_function_name = "my-lambda-function"
  image_uri            = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:1.0.0"
  vpc_id               = "vpc-0123456789abcdef0"
  private_subnet_ids   = ["subnet-0123456789abcdef0", "subnet-abcdef01234567890"]
  
  tags = {
    Environment = "production"
    Owner       = "team@example.com"
    Project     = "my-app"
    Team        = "platform"
    Contact     = "team@example.com"
    CostCenter  = "engineering"
  }
}
```

### All variables

```hcl
module "lambda_function" {
  source = "git::https://github.com/jayaprakashvishnu/terraform-aws-lambda.git?ref=v1.0.0"

  lambda_function_name             = "my-lambda-function"
  image_uri                        = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:1.0.0"
  vpc_id                           = "vpc-0123456789abcdef0"
  private_subnet_ids               = ["subnet-0123456789abcdef0", "subnet-abcdef01234567890"]
  entry_point                      = ["/lambda-entrypoint.sh"]
  command                          = ["app.handler"]
  variables                        = {
    APP_ENV = "production"
  }
  memory_size                      = 512
  timeout                          = 30
  architectures                    = ["x86_64"]
  cloudwatch_log_retention_in_days = 30
  enable_key_rotation              = true
  rotation_period_in_days          = 365
  deletion_window_in_days          = 10
  
  tags = {
    Environment = "production"
    Owner       = "team@example.com"
    Project     = "my-app"
    Team        = "platform"
    Contact     = "team@example.com"
    CostCenter  = "engineering"
  }
}
```

The execution role receives `ecr:GetAuthorizationToken` and image-pull
permissions (`ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer`) scoped to
the ECR repository extracted from `image_uri`. The repository must be in the 
same AWS account as the module deployment. Do not store secrets in Lambda 
environment variables; use a secrets service and grant the execution role 
only the required access.

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|:---:|
| `lambda_function_name` | Name of the Lambda function and supporting resources (1-64 characters). | `string` | n/a | yes |
| `image_uri` | ECR image URI containing the deployment package. Repository ARN is automatically extracted. | `string` | n/a | yes |
| `private_subnet_ids` | IDs of private subnets in which to place the function. | `list(string)` | n/a | yes |
| `vpc_id` | VPC ID containing the private subnets. | `string` | n/a | yes |
| `tags` | Tags applied to created resources. Must include: Environment, Owner, Project, Team, Contact, CostCenter. | `object({...})` | n/a | yes |
| `entry_point` | Optional container entry point override. | `list(string)` | `[]` | no |
| `command` | Optional container command override. | `list(string)` | `[]` | no |
| `variables` | Lambda environment variables; do not store secrets here. | `map(string)` | `{}` | no |
| `memory_size` | Function memory in MB (128-10240). | `number` | `128` | no |
| `timeout` | Maximum execution time in seconds (1-900). | `number` | `3` | no |
| `architectures` | One supported Lambda architecture: `x86_64` or `arm64`. | `list(string)` | `["x86_64"]` | no |
| `cloudwatch_log_retention_in_days` | CloudWatch Logs retention period. | `number` | `7` | no |
| `enable_key_rotation` | Whether automatic KMS key rotation is enabled. | `bool` | `true` | no |
| `rotation_period_in_days` | KMS key rotation period (90-2560 days). | `number` | `365` | no |
| `deletion_window_in_days` | KMS deletion waiting period (7-30 days). | `number` | `10` | no |

## Implementation Details

The module automatically extracts the ECR repository name and region from the 
`image_uri` variable and constructs the appropriate IAM policy permissions. The 
IAM execution role follows the principle of least privilege:

- **CloudWatch Logs**: Scoped to the specific log group created for this function
- **ECR Permissions**: Scoped to the specific repository with account condition
- **VPC Network Interfaces**: Minimum required EC2 permissions for Lambda VPC execution
- **KMS**: Customer-managed key with automatic rotation enabled by default
