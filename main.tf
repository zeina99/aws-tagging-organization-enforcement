

################################################################################
# Data Sources
################################################################################

# Fetch all accounts from AWS Organizations
data "aws_organizations_organization" "org" {}

# Get all active accounts from the organization
locals {
  # Extract all active account IDs from the organization
  org_account_ids = [
    for account in data.aws_organizations_organization.org.accounts : account.id
    if account.status == "ACTIVE"
  ]

  # Filter out excluded accounts (like management account)
  ssm_shared_accounts = [
    for account_id in local.org_account_ids : account_id
    if !contains(var.conformance_pack_excluded_accounts, account_id) && account_id != var.target_account_id
  ]
}

################################################################################
# Tagging Enforcer Module
################################################################################

module "tagging_enforcer" {
  source = "./tagging-module"
  # Audit Account ID
  target_account_id = var.target_account_id

  # DynamoDB Configuration
  dynamodb_table_name = var.dynamodb_table_name
  required_tags       = var.required_tags
  
  # Lambda Configuration
  lambda_evaluator_function_name = var.lambda_evaluator_function_name
  lambda_evaluator_role_name     = var.lambda_evaluator_role_name

  # SSM Document Configuration
  ssm_document_name            = var.ssm_document_name
  ssm_document_shared_accounts = local.ssm_shared_accounts

  # Config Configuration
  conformance_pack_name              = var.conformance_pack_name
  conformance_pack_excluded_accounts = var.conformance_pack_excluded_accounts
  config_rule_name                   = var.config_rule_name

  # Remediation Configuration
  enable_automatic_remediation = var.enable_automatic_remediation
  max_automatic_attempts       = var.max_automatic_attempts
  retry_attempt_seconds        = var.retry_attempt_seconds

  # Config Execution Role
  config_remediation_role_name = var.config_remediation_role_name
  ssm_document_template_file   = var.ssm_document_template_file

  # Tags
  tags = var.tags
}
