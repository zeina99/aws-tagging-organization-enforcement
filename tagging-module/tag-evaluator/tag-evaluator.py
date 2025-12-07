import botocore 
import boto3
import json
import os
from datetime import datetime

# Set to True to get the lambda to assume the Role attached on the Config Service (useful for cross-account).
ASSUME_ROLE_MODE = True

dynamodb = boto3.resource("dynamodb")
DYNAMODB_TABLE_NAME = os.environ["DYNAMODB_TABLE"]
ACCOUNTID_KEY = os.environ["ACCOUNTID_KEY"]
IAM_ROLE_NAME = os.environ["IAM_ROLE_NAME"]

table = dynamodb.Table(f"{DYNAMODB_TABLE_NAME}")

# This gets the client after assuming the Config service role
# either in the same AWS account or cross-account.
def get_client(service, event, account_id):
    """Return the service boto client. It should be used instead of directly calling the client.
    Keyword arguments:
    service -- the service name used for calling the boto.client()
    event -- the event variable given in the lambda handler
    """
    if not ASSUME_ROLE_MODE:
        return boto3.client(service)
    # credentials = get_assume_role_credentials(event["executionRoleArn"])
    credentials = get_assume_role_credentials(f"arn:aws:iam::{account_id}:role/{IAM_ROLE_NAME}")
    return boto3.client(service, aws_access_key_id=credentials['AccessKeyId'],
                        aws_secret_access_key=credentials['SecretAccessKey'],
                        aws_session_token=credentials['SessionToken']
                       )

def get_assume_role_credentials(role_arn):
    sts_client = boto3.client('sts')
    try:
        assume_role_response = sts_client.assume_role(RoleArn=role_arn, RoleSessionName="configLambdaExecution")
        return assume_role_response['Credentials']
    except botocore.exceptions.ClientError as ex:
        # Scrub error message for any internal account info leaks
        if 'AccessDenied' in ex.response['Error']['Code']:
            ex.response['Error']['Message'] = "AWS Config does not have permission to assume the IAM role."
        else:
            ex.response['Error']['Message'] = "InternalError"
            ex.response['Error']['Code'] = "InternalError"
        raise ex


def lambda_handler(event, context):
    """
    AWS Config custom rule to evaluate if resources have required tags.
    """
    try:
        # Parse the invoking event
        invoking_event = json.loads(event['invokingEvent'])
        configuration_item = invoking_event.get('configurationItem', {})
        
        account_id = configuration_item.get("awsAccountId")
        resource_id = configuration_item.get("resourceId")
        resource_type = configuration_item.get("resourceType")
        configuration_item_status = configuration_item.get("configurationItemStatus")

        if configuration_item_status == 'ResourceDeleted':
            print(f"Resource {resource_id} has been deleted")
            return put_evaluation(
                account_id,
                event,
                'NOT_APPLICABLE',
                resource_type,
                resource_id,
                'Resource has been deleted'
            )

        # Fetch required tags from DynamoDB
        try:
            dynamodb_table_response = table.get_item(Key={ACCOUNTID_KEY: account_id})
            table_item = dynamodb_table_response.get("Item", {})
            required_tags = table_item.get("tags", {})
            # Convert to dict if it's not already (DynamoDB returns as dict)
            if not isinstance(required_tags, dict):
                required_tags = {}
            print(f"Required tags: {required_tags}")
        except Exception as e:
            print(f"Error fetching tags from DynamoDB for account {account_id}: {str(e)}")
            raise Exception(f"Failed to retrieve required tags from DynamoDB: {str(e)}")

        resource_tags = configuration_item.get("tags", {})
        # Convert to dict if it's a list (backward compatibility)
        if isinstance(resource_tags, list):
            resource_tags = {}
        elif not isinstance(resource_tags, dict):
            resource_tags = {}

        if not required_tags:
            print(f"No tags found for account {account_id}")
            raise Exception(f"No tags found for account {account_id}")

        # Check for required tags (both keys and values)
        missing_tags = []
        incorrect_tags = []
        
        for tag_key, tag_value in required_tags.items():
            if tag_key not in resource_tags:
                missing_tags.append(tag_key)
            elif resource_tags[tag_key] != tag_value:
                incorrect_tags.append(f"{tag_key} (expected: {tag_value}, actual: {resource_tags[tag_key]})")
        
        print(f"Missing tags: {missing_tags}")
        print(f"Incorrect tags: {incorrect_tags}")

        if missing_tags or incorrect_tags:
            compliance_type = 'NON_COMPLIANT'
            issues = []
            if missing_tags:
                issues.append(f"Missing: {', '.join(missing_tags)}")
            if incorrect_tags:
                issues.append(f"Incorrect values: {', '.join(incorrect_tags)}")
            annotation = "; ".join(issues)
            print(f"Resource {resource_id} is NON_COMPLIANT. {annotation}")
        else:
            compliance_type = 'COMPLIANT'
            annotation = 'All required tags are present with correct values'
            print(f"Resource {resource_id} is COMPLIANT")
        
        # Submit evaluation result
        return put_evaluation(
            account_id,
            event,
            compliance_type,
            resource_type,
            resource_id,
            annotation
        )
    
    except Exception as e:
        print(f"Error in lambda_handler: {str(e)}")
        raise
    


def put_evaluation(account_id, event, compliance_type, resource_type, resource_id, annotation):
    """
    Put evaluation result back to AWS Config.
    """
    evaluation = {
        'ComplianceResourceType': resource_type,
        'ComplianceResourceId': resource_id,
        'ComplianceType': compliance_type,
        'Annotation': annotation,
        'OrderingTimestamp': datetime.now()
    }
    
    result_token = event.get('resultToken')

    config_client = get_client('config', event, account_id)
    
    if result_token and result_token != 'No token found':
        try:
            response = config_client.put_evaluations(
                Evaluations=[evaluation],
                ResultToken=result_token
            )
            # print(f"Put evaluation response: {json.dumps(response, default=str)}")

            
            if response.get('FailedEvaluations'):
                print(f"Failed evaluations: {response['FailedEvaluations']}")
                raise Exception('Failed to submit evaluation to AWS Config')
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Evaluation submitted successfully',
                    'compliance': compliance_type,
                    'resource': resource_id
                })
            }
        except Exception as e:
            print(f"Error putting evaluation: {str(e)}")
            raise
    else:
        print("No result token found - evaluation not submitted")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'No result token - evaluation not submitted',
                'compliance': compliance_type,
                'resource': resource_id
            })
        }