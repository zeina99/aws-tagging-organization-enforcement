################################################################################
# General Variables
################################################################################

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}

variable "target_account_id" {
  description = "AWS Account ID for the Audit account"
  type        = string
}

################################################################################
# DynamoDB Variables
################################################################################

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for storing tags"
  type        = string
  # default     = "tags_table"
}

variable "required_tags" {
  description = "Map of account IDs to maps of required tag key-value pairs. Only accounts explicitly listed here will have required tags enforced."
  type        = map(map(string))
  default     = {}
}

################################################################################
# Lambda Variables
################################################################################

variable "lambda_evaluator_function_name" {
  description = "Name of the Lambda function for tag evaluation"
  type        = string
}

variable "lambda_evaluator_role_name" {
  description = "Name of the IAM role for Lambda evaluator"
  type        = string
  default     = "tags_evaluator_lambda_role"
}

variable "config_remediation_role_name" {
  description = "Name of the IAM role that Lambda assumes in member accounts for Config remediation"
  type        = string
  default     = "ConfigRemediationRole"
}

variable "config_evaluation_role_name" {
  description = "Name of the IAM role that Lambda will assume to evaluate resources (created by CloudFormation StackSet)"
  type        = string
  default     = "ConfigEvaluationRole"
}

variable "ssm_document_template_file" {
  description = "Name of the SSM document template file in the templates directory"
  type        = string
  default     = "remediate_missing_tags_ssm_doc.yaml"
}

################################################################################
# SSM Document Variables
################################################################################

variable "ssm_document_name" {
  description = "Name of the SSM document for remediation"
  type        = string
  default     = "RemediateMissingTags"
}

variable "ssm_document_shared_accounts" {
  description = "List of account IDs to share the SSM document with"
  type        = list(string)
  default     = []
}

################################################################################
# Config Variables
################################################################################

variable "conformance_pack_name" {
  description = "Name of the Config conformance pack"
  type        = string
  default     = "tagging-conformance-pack"
}

variable "conformance_pack_template_file" {
  description = "Name of the conformance pack template file in the templates directory"
  type        = string
  default     = "conformance_pack.yaml"
}

variable "conformance_pack_excluded_accounts" {
  description = "List of account IDs to exclude from the conformance pack"
  type        = list(string)
  default     = []
}

variable "config_rule_name" {
  description = "Name of the Config rule for tag evaluation"
  type        = string
  default     = "tag-evaluator"
}

################################################################################
# Remediation Variables
################################################################################

variable "enable_automatic_remediation" {
  description = "Enable automatic remediation for non-compliant resources"
  type        = bool
  default     = false
}

variable "max_automatic_attempts" {
  description = "Maximum number of automatic remediation attempts"
  type        = number
  default     = 3
}

variable "retry_attempt_seconds" {
  description = "Time in seconds between retry attempts"
  type        = number
  default     = 60
}
