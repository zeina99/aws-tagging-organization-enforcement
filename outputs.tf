################################################################################
# Tagging Enforcer Outputs
################################################################################

output "audit_account_id" {
  description = "AWS Audit Account ID"
  value       = module.tagging_enforcer.account_id
}

output "audit_region" {
  description = "AWS Region for Audit account"
  value       = module.tagging_enforcer.region
}

output "organization_id" {
  description = "AWS Organization ID"
  value       = module.tagging_enforcer.organization_id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = module.tagging_enforcer.dynamodb_table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = module.tagging_enforcer.dynamodb_table_arn
}

output "lambda_evaluator_role_arn" {
  description = "ARN of the Lambda evaluator IAM role"
  value       = module.tagging_enforcer.lambda_evaluator_role_arn
}


output "ssm_document_name" {
  description = "Name of the SSM remediation document"
  value       = module.tagging_enforcer.ssm_document_name
}

output "ssm_document_arn" {
  description = "ARN of the SSM remediation document"
  value       = module.tagging_enforcer.ssm_document_arn
}

output "conformance_pack_name" {
  description = "Name of the Config conformance pack"
  value       = module.tagging_enforcer.conformance_pack_name
}

output "conformance_pack_arn" {
  description = "ARN of the Config conformance pack"
  value       = module.tagging_enforcer.conformance_pack_arn
}
