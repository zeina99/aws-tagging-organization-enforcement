################################################################################
# IAM Role for Lambda Evaluator
################################################################################

resource "aws_iam_role" "tags_evaluator_lambda_role" {
  name = var.lambda_evaluator_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

################################################################################
# AWS Managed Policy for Lambda Logging
################################################################################

resource "aws_iam_role_policy_attachment" "evaluator_lambda_logs" {
  role       = aws_iam_role.tags_evaluator_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

################################################################################
# Inline Policy for Lambda to Assume Config Evaluation Role
################################################################################

resource "aws_iam_role_policy" "lambda_assume_config_role" {
  name = "lambda-assume-config-org-rule"
  role = aws_iam_role.tags_evaluator_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "AssumeConfigEvaluationRole",
        Effect   = "Allow",
        Action   = "sts:AssumeRole",
        Resource = "arn:aws:iam::*:role/${var.config_evaluation_role_name}"
      }
    ]
  })
}

################################################################################
# IAM Role for Config Remediation (SSM Automation)
# Note: This role is created via CloudFormation StackSet in member accounts
# We only need to construct the ARN for reference in the conformance pack
################################################################################

# No Terraform resource needed - role is managed by CloudFormation StackSet
