# file: lambda_function.py
import boto3
import json
import logging
import urllib.request
from typing import Dict, List, Set

logger = logging.getLogger()
logger.setLevel(logging.INFO)

organizations = boto3.client("organizations")
ssm = boto3.client("ssm")
sts = boto3.client("sts")


def send_cfn_response(event, context, status, response_data, physical_resource_id=None, reason=None):
    """
    Send a response to CloudFormation for Custom Resource requests.
    """
    response_url = event.get("ResponseURL")
    if not response_url:
        logger.info("No ResponseURL found - not a CloudFormation Custom Resource event")
        return

    physical_resource_id = physical_resource_id or event.get("PhysicalResourceId") or (
        context.log_stream_name if context else "unknown"
    )

    response_body = {
        "Status": status,
        "Reason": reason or f"See CloudWatch Log Stream: {context.log_stream_name if context else 'N/A'}",
        "PhysicalResourceId": physical_resource_id,
        "StackId": event.get("StackId", ""),
        "RequestId": event.get("RequestId", ""),
        "LogicalResourceId": event.get("LogicalResourceId", ""),
        "NoEcho": False,
        "Data": response_data or {},
    }

    json_body = json.dumps(response_body)
    logger.info("Sending CloudFormation response: %s", json_body)

    try:
        req = urllib.request.Request(
            response_url,
            data=json_body.encode("utf-8"),
            headers={"Content-Type": ""},
            method="PUT",
        )
        with urllib.request.urlopen(req) as response:
            logger.info("CloudFormation response sent successfully: %s", response.read().decode("utf-8"))
    except Exception as e:
        logger.error("Failed to send CloudFormation response: %s", e)


def chunk_list(items: List[str], size: int = 20) -> List[List[str]]:
    """Yield successive chunks from list."""
    return [items[i : i + size] for i in range(0, len(items), size)]


def list_active_accounts() -> Dict[str, Dict[str, str]]:
    """
    Return dict of account_id -> {Id, Name, Status} for ACTIVE accounts.
    """
    accounts: Dict[str, Dict[str, str]] = {}
    paginator = organizations.get_paginator("list_accounts")
    for page in paginator.paginate():
        for account in page.get("Accounts", []):
            if account.get("Status") == "ACTIVE":
                accounts[account["Id"]] = {
                    "Id": account["Id"],
                    "Name": account.get("Name", "Unknown"),
                    "Status": account["Status"],
                }
    logger.info("Found %s active accounts", len(accounts))
    return accounts


def get_document_shared_accounts(document_id: str) -> Set[str]:
    """Return set of account IDs the document is already shared with."""
    response = ssm.describe_document_permission(
        Name=document_id,
        PermissionType="Share",
    )
    shares = set(response.get("AccountIds", []))
    logger.info("Document currently shared with %s accounts", len(shares))
    return shares


def update_document_permissions(
    document_id: str,
    accounts_to_add: Set[str],
    accounts_to_remove: Set[str],
) -> Dict[str, List[str]]:
    """Share/unshare the document with the provided account IDs."""
    results = {"added": [], "removed": []}

    for chunk in chunk_list(list(accounts_to_add)):
        ssm.modify_document_permission(
            Name=document_id,
            PermissionType="Share",
            AccountIdsToAdd=chunk,
        )
        results["added"].extend(chunk)
        logger.info("Shared document %s with accounts %s", document_id, chunk)

    for chunk in chunk_list(list(accounts_to_remove)):
        ssm.modify_document_permission(
            Name=document_id,
            PermissionType="Share",
            AccountIdsToRemove=chunk,
        )
        results["removed"].extend(chunk)
        logger.info("Removed document %s share from accounts %s", document_id, chunk)

    return results


def get_current_account_id() -> str:
    return sts.get_caller_identity()["Account"]


def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    # Check if this is a CloudFormation Custom Resource event
    is_cfn_event = "ResponseURL" in (event or {})
    request_type = event.get("RequestType", "")

    # For CloudFormation Delete requests, just return success (no cleanup needed)
    if is_cfn_event and request_type == "Delete":
        logger.info("CloudFormation Delete request - nothing to clean up")
        send_cfn_response(event, context, "SUCCESS", {"Message": "Delete successful"})
        return {"statusCode": 200, "message": "Delete successful"}

    # Get document_id from either direct event or CloudFormation ResourceProperties
    if is_cfn_event:
        resource_properties = event.get("ResourceProperties", {})
        document_id = resource_properties.get("document_id") or resource_properties.get("DocumentId")
    else:
        document_id = (event or {}).get("document_id")

    if not document_id:
        error_msg = "document_id must be provided in event payload"
        logger.error(error_msg)
        if is_cfn_event:
            send_cfn_response(event, context, "FAILED", {}, reason=error_msg)
        return {"statusCode": 400, "error": error_msg}

    logger.info("Processing document %s", document_id)

    try:
        active_accounts = list_active_accounts()
        current_account = get_current_account_id()

        if not active_accounts:
            logger.info("No active accounts found")
            response_data = {
                "Message": "No active accounts found",
                "DocumentId": document_id,
                "AddedAccounts": "0",
                "RemovedAccounts": "0",
            }
            if is_cfn_event:
                send_cfn_response(event, context, "SUCCESS", response_data, physical_resource_id=document_id)
            return {
                "statusCode": 200,
                "message": "No active accounts found",
                "document_id": document_id,
                "added_accounts": [],
                "removed_accounts": [],
            }

        shared_accounts = get_document_shared_accounts(document_id)

        active_ids = set(active_accounts.keys())
        shared_ids = set(shared_accounts)

        if current_account in shared_ids:
            shared_ids.remove(current_account)

        accounts_to_add = active_ids - shared_ids
        if current_account in accounts_to_add:
            accounts_to_add.remove(current_account)

        accounts_to_remove = shared_ids - active_ids

        changes = update_document_permissions(
            document_id,
            accounts_to_add,
            accounts_to_remove,
        )

        response_data = {
            "DocumentId": document_id,
            "ActiveAccounts": str(len(active_accounts)),
            "CurrentlySharedAccounts": str(len(shared_accounts)),
            "AddedAccounts": str(len(changes["added"])),
            "RemovedAccounts": str(len(changes["removed"])),
        }

        if is_cfn_event:
            send_cfn_response(event, context, "SUCCESS", response_data, physical_resource_id=document_id)

        return {
            "statusCode": 200,
            "document_id": document_id,
            "active_accounts": len(active_accounts),
            "currently_shared_accounts": len(shared_accounts),
            "added_accounts": changes["added"],
            "removed_accounts": changes["removed"],
        }

    except ssm.exceptions.DocumentDoesNotExist:
        error_msg = f"Document '{document_id}' does not exist"
        logger.error("Document %s does not exist", document_id)
        if is_cfn_event:
            send_cfn_response(event, context, "FAILED", {}, reason=error_msg)
        return {"statusCode": 404, "error": error_msg}

    except Exception as exc:
        error_msg = str(exc)
        logger.error("Failed to update permissions: %s", exc, exc_info=True)
        if is_cfn_event:
            send_cfn_response(event, context, "FAILED", {}, reason=error_msg)
        return {"statusCode": 500, "error": error_msg}
