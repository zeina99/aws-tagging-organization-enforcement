################################################################################
# Lambda Permission for Config to Invoke Function
################################################################################

resource "aws_lambda_permission" "config_invoke" {
  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.evaluator_lambda.arn
  principal     = "config.amazonaws.com"
  statement_id  = "AllowExecutionFromConfig"
}

############################################
# CLOUDWATCH LOG GROUPS
############################################
resource "aws_cloudwatch_log_group" "evaluator_lambda_logs" {
  name              = "/aws/lambda/tag-evaluator"
  retention_in_days = 90
}

############################################
# PACKAGE PYTHON LAMBDA CODE
############################################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/tag-evaluator"
  output_path = "${path.module}/lambda.zip"
}

############################################
# LAMBDA FUNCTION
############################################
resource "aws_lambda_function" "evaluator_lambda" {
  function_name = "tag-evaluator"

  handler = "tag-evaluator.lambda_handler"
  runtime = "python3.12"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  role    = aws_iam_role.tags_evaluator_lambda_role.arn
  timeout = 300

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.evaluator_lambda_logs.name
  }

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.tags_table.arn
      ACCOUNTID_KEY  = aws_dynamodb_table.tags_table.hash_key
      IAM_ROLE_NAME  = var.config_evaluation_role_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.evaluator_lambda_logs,
    aws_iam_role_policy_attachment.evaluator_lambda_logs
  ]
}


############################################
# PACKAGE SSM DOCUMENT SHARING LAMBDA CODE
############################################
data "archive_file" "share_ssm_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/share-ssm-doc-lambda"
  output_path = "${path.module}/share-ssm-doc-lambda.zip"
}

