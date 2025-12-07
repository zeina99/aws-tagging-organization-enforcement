# Tagging Enforcer Module

This module deploys AWS Config tagging compliance and enforcement resources into the Audit account of the AWS Control Tower Landing Zone.

## Overview

The module creates the following resources in the Audit account:
- **DynamoDB Table**: Stores tag requirements for accounts
- **Lambda IAM Role**: Allows Lambda to evaluate tag compliance
- **Config Remediation IAM Role**: Allows SSM Automation to remediate non-compliant resources
- **SSM Document**: Automation document for tag remediation
- **Config Organization Conformance Pack**: Organization-wide Config rule for tag evaluation and remediation

## Prerequisites

1. AWS Control Tower deployed
2. Audit account configured as delegated administrator for AWS Config
3. CloudFormation StackSet deployed to create `ConfigEvaluationRole` in all member accounts
4. SSM remediation script template available at `templates/remediate_missing_tags_ssm_doc.yaml`

## Usage

### Basic Usage

```hcl
module "tagging_enforcer" {
  source = "./modules/tagging-enforcer"

  # DynamoDB Configuration
  dynamodb_table_name = "required-tags-table"

  # Lambda Configuration
  lambda_evaluator_function_name = "tag-evaluator"
  lambda_evaluator_role_name     = "tags_evaluator_lambda_role"

  # SSM Document Configuration
  ssm_document_name            = "RemediateMissingTags"
  ssm_document_shared_accounts = ["701589665035", "814314855263"]

  # Config Configuration
  conformance_pack_name              = "tagging-conformance-pack"
  conformance_pack_excluded_accounts = ["108080471788"]
  config_rule_name                   = "tag-evaluator"

  # IAM Roles
  config_remediation_role_name = "ConfigRemediationRole"
  config_evaluation_role_name  = "ConfigEvaluationRole"

  tags = {
    ProjectName = "Landing Zone Tagging"
    Environment = "Prod"
    ManagedBy   = "Terraform"
  }
}
```

### With Automatic Remediation

```hcl
module "tagging_enforcer" {
  source = "./modules/tagging-enforcer"

  dynamodb_table_name            = "required-tags-table"
  lambda_evaluator_function_name = "tag-evaluator"
  conformance_pack_name          = "tagging-conformance-pack"

  # Enable automatic remediation (use with caution)
  enable_automatic_remediation = true
  max_automatic_attempts       = 5
  retry_attempt_seconds        = 120

  tags = {
    ProjectName = "Landing Zone Tagging"
    Environment = "Prod"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| dynamodb_table_name | Name of the DynamoDB table for storing tags | string | - | yes |
| lambda_evaluator_function_name | Name of the Lambda function for tag evaluation | string | - | yes |
| lambda_evaluator_role_name | Name of the IAM role for Lambda evaluator | string | "tags_evaluator_lambda_role" | no |
| config_remediation_role_name | Name of the IAM role for Config remediation | string | "ConfigRemediationRole" | no |
| config_evaluation_role_name | Name of the IAM role Lambda assumes for evaluation | string | "ConfigEvaluationRole" | no |
| ssm_document_name | Name of the SSM document for remediation | string | "RemediateMissingTags" | no |
| ssm_document_template_file | SSM document template file name | string | "remediate_missing_tags_ssm_doc.yaml" | no |
| ssm_document_shared_accounts | Accounts to share SSM document with | list(string) | [] | no |
| conformance_pack_name | Name of the Config conformance pack | string | "tagging-conformance-pack" | no |
| conformance_pack_template_file | Conformance pack template file name | string | "conformance_pack.yaml" | no |
| conformance_pack_excluded_accounts | Accounts to exclude from conformance pack | list(string) | [] | no |
| config_rule_name | Name of the Config rule for tag evaluation | string | "tag-evaluator" | no |
| enable_automatic_remediation | Enable automatic remediation | bool | false | no |
| max_automatic_attempts | Max automatic remediation attempts | number | 3 | no |
| retry_attempt_seconds | Seconds between retry attempts | number | 60 | no |
| tags | Common tags for all resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| account_id | AWS Account ID |
| region | AWS Region |
| organization_id | AWS Organization ID |
| dynamodb_table_name | Name of the DynamoDB table |
| dynamodb_table_arn | ARN of the DynamoDB table |
| lambda_evaluator_role_arn | ARN of the Lambda evaluator IAM role |

| ssm_document_name | Name of the SSM remediation document |
| ssm_document_arn | ARN of the SSM remediation document |
| conformance_pack_name | Name of the Config conformance pack |
| conformance_pack_arn | ARN of the Config conformance pack |

## Resources Created

- `aws_dynamodb_table.tags_table` - DynamoDB table for tag storage
- `aws_dynamodb_table_resource_policy.tags_table_policy` - Resource policy for DynamoDB table
- `aws_iam_role.tags_evaluator_lambda_role` - IAM role for Lambda evaluator
- `aws_iam_role_policy_attachment.lambda_logs` - Managed policy for Lambda logging
- `aws_iam_role_policy.lambda_dynamodb_access` - Inline policy for DynamoDB access
- `aws_iam_role_policy.lambda_assume_config_role` - Inline policy for assuming Config evaluation role
- `aws_lambda_function.evaluator_lambda` - Lambda function for tag evaluation
- `aws_lambda_permission.config_invoke` - Permission for Config to invoke Lambda
- `aws_ssm_document.remediate_missing_tags` - SSM automation document
- `aws_config_organization_conformance_pack.tagging` - Config conformance pack

## Notes

1. The Lambda function is deployed by this module from the `tag-evaluator/` directory
2. The SSM remediation script template must exist at `templates/remediate_missing_tags_ssm_doc.yaml`
3. The conformance pack template must exist at `templates/conformance_pack.yaml`
4. The conformance pack applies organization-wide (except excluded accounts)
5. Automatic remediation is disabled by default for safety
6. The `ConfigEvaluationRole` must be created in all member accounts via CloudFormation StackSet

## Deployment Steps

1. Ensure prerequisites are met
2. Configure variables in `terraform.tfvars`
3. Initialize Terraform:
   ```bash
   terraform init
   ```
4. Review the plan:
   ```bash
   terraform plan
   ```
5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Troubleshooting

- **Conformance pack creation timeout**: Increase timeout in the conformance pack resource (default: 20 minutes)
- **Lambda function not found**: Ensure the `tag-evaluator/` directory contains the Lambda source code
- **SSM document not found**: Ensure `templates/remediate_missing_tags_ssm_doc.yaml` exists
- **Config evaluation fails**: Verify `ConfigEvaluationRole` exists in member accounts with proper trust policy
- **DynamoDB access denied**: Check that the Lambda role has permissions and the resource policy is correct
