################################################################################
# DynamoDB Table for Tags Storage
################################################################################

resource "aws_dynamodb_table" "tags_table" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "account_id"

  attribute {
    name = "account_id"
    type = "S"
  }

  tags = merge(
    var.tags,
    {
      Name = var.dynamodb_table_name
    }
  )
}

resource "aws_dynamodb_resource_policy" "tags_table_policy" {
  resource_arn = aws_dynamodb_table.tags_table.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaEvaluatorRoleFromOrgAccounts"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "dynamodb:GetItem"
        Resource = aws_dynamodb_table.tags_table.arn
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = data.aws_organizations_organization.org.id
          }
          ArnEquals = {
            "aws:PrincipalArn" = "arn:aws:iam::*:role/${var.lambda_evaluator_role_name}"
          }
        }
      },
      {
        Sid    = "AllowRemediationRoleFromOrgAccounts"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "dynamodb:GetItem"
        Resource = aws_dynamodb_table.tags_table.arn
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = data.aws_organizations_organization.org.id
          }
          ArnLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/${var.config_remediation_role_name}",
              "arn:aws:sts::*:assumed-role/${var.config_remediation_role_name}/*"
            ]
          }
        }
      }
    ]
  })
}

################################################################################
# DynamoDB Table Items for Required Tags
################################################################################

locals {
  # Get all active account IDs from organization
  org_account_ids = [
    for account in data.aws_organizations_organization.org.accounts : account.id
    if account.status == "ACTIVE"
  ]
  
  # Create a map of account_id to required tags
  # Only include accounts that are explicitly defined in var.required_tags
  account_tags_map = {
    for account_id in local.org_account_ids : account_id => var.required_tags[account_id]
    if contains(keys(var.required_tags), account_id)
  }
}

# Create DynamoDB items for each account with required tags
resource "aws_dynamodb_table_item" "required_tags" {
  for_each = {
    for account_id, tags in local.account_tags_map : account_id => tags
    if length(tags) > 0  # Only create items if there are tags to store
  }

  table_name = aws_dynamodb_table.tags_table.name
  hash_key   = aws_dynamodb_table.tags_table.hash_key

  item = jsonencode({
    account_id = {
      S = each.key
    }
    tags = {
      M = {
        for tag_key, tag_value in each.value : tag_key => {
          S = tag_value
        }
      }
    }
  })
}
