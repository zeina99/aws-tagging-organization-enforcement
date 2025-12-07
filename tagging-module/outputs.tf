################################################################################
# Outputs
################################################################################

output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS Region"
  value       = data.aws_region.current.id
}

output "organization_id" {
  description = "AWS Organization ID"
  value       = data.aws_organizations_organization.org.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.tags_table.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.tags_table.arn
}

output "lambda_evaluator_role_arn" {
  description = "ARN of the Lambda evaluator IAM role"
  value       = aws_iam_role.tags_evaluator_lambda_role.arn
}


output "ssm_document_name" {
  description = "Name of the SSM remediation document"
  value       = aws_ssm_document.remediate_missing_tags.name
}

output "ssm_document_arn" {
  description = "ARN of the SSM remediation document"
  value       = aws_ssm_document.remediate_missing_tags.arn
}

output "conformance_pack_name" {
  description = "Name of the Config conformance pack"
  value       = aws_config_organization_conformance_pack.tagging.name
}

output "conformance_pack_arn" {
  description = "ARN of the Config conformance pack"
  value       = aws_config_organization_conformance_pack.tagging.arn
}
