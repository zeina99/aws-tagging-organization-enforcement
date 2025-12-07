# AWS Config Tagging Compliance and Enforcement

This repository contains Terraform and CloudFormation templates to deploy an automated tagging compliance and enforcement solution for AWS Control Tower Landing Zones. The solution uses AWS Config to evaluate resource tag compliance and automatically remediate non-compliant resources.

## Overview

This solution provides organization-wide tag compliance enforcement by:

- **Storing tag requirements** in a DynamoDB table (key-value pairs per account)
- **Evaluating compliance** using AWS Config custom rules with Lambda functions
- **Automatically remediating** non-compliant resources using SSM Automation documents
- **Supporting account-specific** tag requirements

## Prerequisites

Before deploying this solution, ensure you have:

1. **AWS Control Tower** deployed and configured
2. **Audit Account** configured as delegated administrator for AWS Config
3. **Terraform** installed (version >= 1.0)
4. **AWS CLI** configured with appropriate credentials
5. **IAM Permissions** to:
   - Create IAM roles and policies
   - Create Lambda functions
   - Create DynamoDB tables
   - Create AWS Config conformance packs
   - Create SSM documents
   - Deploy CloudFormation StackSets

## Setup Steps

> **⚠️ Important Deployment Order**: The CloudFormation StackSet **must be deployed AFTER Terraform** because it requires the Lambda execution role ARN that is created by Terraform. Deploying the StackSet before Terraform will fail.

### Step 1: Configure Terraform Variables

1. **Copy and edit** `terraform.tfvars`:

```hcl
# AWS Region
region            = "me-central-1"
target_account_id = "111111111111111"  # Your Audit account ID

# Common Tags
tags = {
  Environment  = "Prod"
  ManagedBy    = "Terraform"
  ProjectName  = "Landing Zone Tagging"
  ProjectOwner = "Cloud Team"
}

# DynamoDB Configuration
dynamodb_table_name = "required-tags-table"

# Required Tags Configuration
# Format: account_id = { tag_key = "tag_value" }
required_tags = {
  "539022696811" = {
    Environment  = "Prod"
    ProjectName  = "CloudTrail"
    ProjectOwner = "Cloud Team"
    ManagedBy    = "Terraform"
  }
  # Add more accounts as needed
}

# Lambda Configuration
lambda_evaluator_function_name = "tag-evaluator"
lambda_evaluator_role_name     = "tags_evaluator_lambda_role"
config_remediation_role_name   = "ConfigRemediationRole"

# SSM Document Configuration
ssm_document_name = "RemediateMissingTags"

# Config Configuration
conformance_pack_name = "tagging-conformance-pack"
config_rule_name      = "tag-evaluator"

# Remediation Configuration
enable_automatic_remediation = true
max_automatic_attempts       = 3
retry_attempt_seconds        = 60
```

### Step 2: Initialize Terraform

```bash
# Initialize Terraform and download providers
terraform init
```

### Step 3: Review Terraform Plan

```bash
# Review what will be created
terraform plan
```

### Step 4: Deploy Terraform Configuration

```bash
# Apply the configuration
terraform apply
```

After Terraform deployment completes, note the Lambda execution role ARN. You can get it from:

```bash
# Get the Lambda role ARN from Terraform output
terraform output

# Or query AWS directly
aws iam get-role --role-name tags_evaluator_lambda_role --query 'Role.Arn' --output text
```

### Step 5: Deploy CloudFormation StackSet for IAM Roles

After Terraform deployment, deploy the CloudFormation StackSet that creates the necessary IAM roles in member accounts.

> **⚠️ Important**: The CloudFormation template (`config-roles.yaml`) includes a default value for `TagEvaluationLambdaExecutionIAMRoleArn` with a placeholder `<LAMBDA_ACCOUNT_ID>`. **You must replace this placeholder with your actual Audit account ID** where the Lambda function is deployed. The default value will work if:
> - The Lambda role name is `tags_evaluator_lambda_role` (default)
> - You replace `<LAMBDA_ACCOUNT_ID>` with your Audit account ID
> 
> Example: If your Audit account ID is `111111111111111`, change:
> - From: `arn:aws:iam::<LAMBDA_ACCOUNT_ID>:role/tags_evaluator_lambda_role`
> - To: `arn:aws:iam::111111111111111:role/tags_evaluator_lambda_role`
> 
> **Alternatively**, you can use the Lambda execution role ARN obtained from Step 4.

#### Deploy via AWS Console StackSets

1. **Navigate to CloudFormation** in the AWS Console
2. **Go to StackSets** in the left navigation menu
3. **Create StackSet** → **With new resources (standard)**
4. **Upload template file**: Select `config-roles.yaml`
5. **Specify StackSet details**:
   - **StackSet name**: `config-tagging-roles` (or your preferred name)
   - **Parameters**:
     - `DynamoDBTableName`: Name of your DynamoDB table (e.g., `required-tags-table`)
     - `DynamoDBAccountID`: Account ID where DynamoDB table is located (Audit account ID)
     - `RemediationRoleName`: Name for remediation role (default: `ConfigRemediationRole`)
     - `TagEvaluationLambdaExecutionIAMRoleArn`: 
       - **Option 1**: Use the Lambda execution role ARN from Step 4 (recommended)
       - **Option 2**: Replace `<LAMBDA_ACCOUNT_ID>` in the default value with your Audit account ID
   
6. **Configure StackSet options**:
   - **Permission model**: Select **"Service-managed permissions"**
   - **Auto-deployment**: Enable **"Enable automatic deployment"** and select **"Deploy to organization"** or **"Deploy to organizational units (OUs)"**
   - **Regions**: Select the region(s) where you want to deploy (e.g., `me-central-1`)
   - **Accounts**: Select the accounts or OUs where you want to deploy the stack instances
7. **Review and create** the StackSet

## Supported Resources

This solution evaluates and can remediate tags for the following AWS resource types:

| Category | Service | Resource Types |
|----------|---------|----------------|
| **Compute & Containers** | EC2 | Instances, Launch Templates, Spot Fleets, Hosts, Capacity Reservations |
| | ECS | Clusters, Services, Task Definitions |
| | EKS | Clusters |
| | Lambda | Functions |
| **Storage** | EC2 | Volumes, Snapshots |
| | S3 | Buckets, Objects |
| | EFS | File Systems |
| **Networking & Content Delivery** | VPC | VPCs, Subnets, Route Tables, Internet Gateways, Egress-Only Internet Gateways |
| | VPC Connectivity | VPC Endpoints, VPC Peering Connections, Transit Gateways, VPN Connections, VPN Gateways |
| | Networking | Network Interfaces, Elastic IPs, NAT Gateways, Security Groups, Flow Logs |
| | Load Balancing | Application Load Balancers, Network Load Balancers, Classic Load Balancers, Target Groups |
| | Route53 | Hosted Zones |
| **Databases** | RDS | DB Instances, DB Clusters, DB Snapshots, DB Cluster Snapshots |
| | DynamoDB | Tables |
| | ElastiCache | Cache Clusters |
| | Redshift | Clusters |
| **Messaging & Integration** | SNS | Topics |
| | SQS | Queues |
| | EventBridge | Rules |
| | Step Functions | State Machines |
| | API Gateway | REST APIs, HTTP APIs |
| **Security, Identity & Compliance** | IAM | Roles, Users, Groups, Policies |
| | Secrets Manager | Secrets |
| | CloudTrail | Trails |
| | ACM | Certificates |
| **Management & Governance** | CloudFormation | Stacks |
| | Systems Manager | Documents, Parameters |
| | CloudWatch | Log Groups |
| | Backup | Backup Plans, Backup Vaults |
| | Organizations | Organizations |
| **Analytics & Big Data** | Kinesis | Streams |
| | Kinesis Firehose | Delivery Streams |
| | Glue | Jobs |
| **Developer Tools** | CodeBuild | Projects |
| | CodePipeline | Pipelines |
| | ECR | Repositories |
| **Desktop & App Streaming** | WorkSpaces | Workspaces |
| **Auto Scaling** | Auto Scaling | Auto Scaling Groups |

> **Note**: The solution uses AWS Config to evaluate resources and the Resource Groups Tagging API for remediation. Resources must be:
> 1. Supported by AWS Config (monitored resource types)
> 2. Tagged via the Resource Groups Tagging API or service-specific tagging APIs
> 3. Have an ARN (resources without ARNs are skipped)

### Adding Support for New Resources

To add support for additional AWS resource types, you need to modify two files:

#### 1. Update Conformance Pack Template

Add the new resource type to the `ComplianceResourceTypes` list in `tagging-module/templates/conformance_pack.yaml`:

```yaml
Resources:
  TagComplianceRule:
    Type: "AWS::Config::ConfigRule"
    Properties:
      Scope:
        ComplianceResourceTypes:
          # ... existing resource types ...
          - "AWS::NewService::ResourceType"  # Add your new resource type here
```

**Resource Type Format**: Use the AWS Config resource type format: `AWS::ServiceName::ResourceType`

**Finding Resource Types**: 
- Check [AWS Config Supported Resource Types](https://docs.aws.amazon.com/config/latest/developerguide/resource-config-reference.html)

#### 2. Update IAM Role Permissions

Add the appropriate tagging permissions to the `ConfigRemediationRole` in `config-roles.yaml`:




Add a new policy statement in the `tagging-access` policy:

```yaml
- Sid: NewServiceTaggingPermissions
  Effect: Allow
  Action:
    - 'newservice:TagResource'          # Service-specific tagging action
    - 'newservice:ListTagsForResource' # List tags action
    - 'newservice:DescribeResource'    # Describe action (if needed)
  Resource: '*'
```


**After Making Changes**:

1. **Update Terraform**: 
   ```bash
   terraform plan  # Review changes
   terraform apply # Apply conformance pack updates
   ```

2. **Update CloudFormation StackSet with new template**



**Important Considerations**:
- Ensure the resource type is supported by AWS Config
- Verify the resource has an ARN (required for tagging)

## Configuration

### Required Tags Format

The `required_tags` variable accepts a map where:
- **Key**: Account ID (string)
- **Value**: Map of tag key-value pairs

Example:
```hcl
required_tags = {
  "123456789012" = {
    Environment  = "Prod"
    ProjectName  = "MyProject"
    ProjectOwner = "Team A"
    ManagedBy    = "Terraform"
  }
  "987623321098" = {
    Environment  = "Dev"
    ProjectName  = "TestProject"
    ProjectOwner = "Team B"
    ManagedBy    = "Terraform"
  }
}
```

### Automatic Remediation

The solution can automatically remediate non-compliant resources:

- **Enable/Disable**: Set `enable_automatic_remediation = true/false`
- **Max Attempts**: Configure `max_automatic_attempts` (default: 3)
- **Retry Delay**: Configure `retry_attempt_seconds` (default: 60)


## How It Works

### 1. Tag Evaluation

- AWS Config invokes the Lambda function when resources change
- Lambda reads required tags from DynamoDB for the account
- Lambda compares resource tags with required tags (both keys and values)
- Config rule reports compliance status

### 2. Tag Remediation

- When a resource is non-compliant, Config triggers SSM Automation
- SSM Automation document:
  - Retrieves required tags from DynamoDB
  - Gets current resource tags
  - Identifies missing or incorrect tags
  - Applies/updates tags using Resource Groups Tagging API

### 3. DynamoDB Structure

Each account has an entry in DynamoDB:
- **Partition Key**: `account_id` (string)
- **Attribute**: `tags` (map of tag key-value pairs)

Example DynamoDB item:
```json
{
  "account_id": "532174696811",
  "tags": {
    "Environment": "Prod",
    "ProjectName": "CloudTrail",
    "ProjectOwner": "Cloud Team",
    "ManagedBy": "Terraform",
  }
}
```

## Verification

### Check DynamoDB Table

```bash
# List items in DynamoDB table
aws dynamodb scan \
  --table-name required-tags-table \
  --region me-central-1
```

### Check Config Compliance

1. Navigate to **AWS Config** → **Rules**
2. Find the `tag-evaluator` rule
3. Check compliance status for resources

### Check Lambda Logs

```bash
# View Lambda function logs
aws logs tail /aws/lambda/tag-evaluator --follow --region me-central-1
```

### Test Remediation

1. Create a test resource without required tags
2. Wait for Config evaluation (or trigger manually)
3. Verify remediation via SSM Automation executions
4. Check that tags were applied correctly

## Troubleshooting

### Issue: CloudFormation StackSet Fails

**Error**: `TagEvaluationLambdaExecutionIAMRoleArn not found` or invalid ARN

**Solution**: Ensure you have deployed Terraform first (Step 4) to create the Lambda role. Then use the Lambda execution role ARN from Terraform output when deploying the StackSet (Step 5). Alternatively, replace `<LAMBDA_ACCOUNT_ID>` in the default parameter value with your Audit account ID.

### Issue: Config Rule Shows "INSUFFICIENT_DATA"

**Possible Causes**:
- Lambda function not invoked yet
- `ConfigEvaluationRole` missing in member account
- Lambda execution errors

**Solution**:
1. Check Lambda CloudWatch logs
2. Verify `ConfigEvaluationRole` exists in member accounts
3. Check Lambda IAM permissions

### Issue: Remediation Not Working

**Possible Causes**:
- `ConfigRemediationRole` missing or incorrect permissions
- SSM document not shared with account
- Resource not taggable

**Solution**:
1. Verify `ConfigRemediationRole` exists in member account
2. Check SSM document sharing configuration
3. Review SSM Automation execution logs
4. Verify resource supports tagging

### Issue: DynamoDB Access Denied

**Possible Causes**:
- Resource policy not applied
- Lambda role missing DynamoDB permissions
- Cross-account access issues

**Solution**:
1. Check DynamoDB resource policy
2. Verify Lambda IAM role has `dynamodb:GetItem` permission
3. Check organization ID matches in resource policy

### Issue: Tags Not Applied to Resources

**Possible Causes**:
- Resource type not supported
- Remediation role missing tagging permissions
- Resource has tag restrictions

**Solution**:
1. Check `config-roles.yaml` includes permissions for resource type
2. Verify remediation role has appropriate tagging actions
3. Check resource-specific tagging requirements

## Cleanup

To remove all resources:

```bash
# Destroy Terraform resources
terraform destroy

# Delete CloudFormation StackSet via Console:
# 1. Navigate to CloudFormation → StackSets
# 2. Select the config-tagging-roles StackSet
# 3. Click "Delete StackSet"
# 4. Confirm deletion

# Or delete StackSet via CLI
aws cloudformation delete-stack-set \
  --stack-set-name config-tagging-roles \
  --region me-central-1
```

## Security Considerations

1. **IAM Roles**: Follow principle of least privilege
2. **DynamoDB**: Resource policy restricts access to organization accounts
3. **Lambda**: Runs with minimal required permissions
4. **SSM Automation**: Uses IAM role with specific resource tagging permissions
5. **Audit**: All actions are logged in CloudTrail

## Support

For issues or questions:
1. Check CloudWatch Logs for Lambda and SSM Automation
2. Review AWS Config compliance history
3. Check Terraform state for resource status
4. Review IAM role policies and trust relationships

