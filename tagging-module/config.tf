# ################################################################################
# # Config Organization Conformance Pack
# ################################################################################

resource "aws_config_organization_conformance_pack" "tagging" {
  name              = var.conformance_pack_name
  excluded_accounts = var.conformance_pack_excluded_accounts

  template_body = templatefile("${path.module}/templates/${var.conformance_pack_template_file}", {
    config_rule_name     = var.config_rule_name
    lambda_evaluator_arn = aws_lambda_function.evaluator_lambda.arn
    ssm_document_arn     = aws_ssm_document.remediate_missing_tags.arn
    # Role is created by CloudFormation StackSet in each member account
    # Using $ACCOUNT_ID placeholder that Config will replace with the actual account ID
    # config_remediation_role_arn  = "arn:aws:iam::$ACCOUNT_ID:role/${var.config_remediation_role_name}"
    audit_account_id             = var.target_account_id
    dynamodb_table_arn           = aws_dynamodb_table.tags_table.arn
    account_id_key               = aws_dynamodb_table.tags_table.hash_key
    enable_automatic_remediation = var.enable_automatic_remediation
    max_automatic_attempts       = var.max_automatic_attempts
    retry_attempt_seconds        = var.retry_attempt_seconds
  })

  depends_on = [
    aws_lambda_permission.config_invoke,
    aws_ssm_document.remediate_missing_tags
  ]
}
