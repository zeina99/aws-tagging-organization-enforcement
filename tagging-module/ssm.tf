################################################################################
# SSM Document for Remediation
################################################################################

resource "aws_ssm_document" "remediate_missing_tags" {
  name            = var.ssm_document_name
  document_type   = "Automation"
  document_format = "YAML"

  permissions = length(var.ssm_document_shared_accounts) > 0 ? {
    account_ids = join(",", var.ssm_document_shared_accounts)
    type        = "Share"
  } : null

  content = file("${path.module}/templates/${var.ssm_document_template_file}")

  tags = var.tags
}
