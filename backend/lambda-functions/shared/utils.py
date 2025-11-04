import json
import boto3
import uuid
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from decimal import Decimal
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def decimal_default(obj):
    """JSON serializer for objects not serializable by default json code"""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")

def create_response(status_code: int, body: Dict[Any, Any], headers: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
    """Create a standardized API response"""
    default_headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }
    
    if headers:
        default_headers.update(headers)
    
    try:
        return {
            'statusCode': status_code,
            'headers': default_headers,
            'body': json.dumps(body, default=decimal_default)
        }
    except Exception as e:
        logger.error(f"Error serializing response: {str(e)}")
        # Fallback response
        return {
            'statusCode': 500,
            'headers': default_headers,
            'body': json.dumps({'error': 'Response serialization error'})
        }

def convert_dynamodb_response(item):
    """Convert DynamoDB response to JSON-serializable format"""
    if isinstance(item, dict):
        return {k: convert_dynamodb_response(v) for k, v in item.items()}
    elif isinstance(item, list):
        return [convert_dynamodb_response(i) for i in item]
    elif isinstance(item, Decimal):
        return float(item)
    else:
        return item

def get_user_from_event(event: Dict[str, Any]) -> Dict[str, Any]:
    """Extract user information from API Gateway event"""
    try:
        claims = event['requestContext']['authorizer']['claims']
        return {
            'userId': claims['sub'],
            'email': claims['email'],
            'role': claims.get('custom:role', 'viewer')
        }
    except KeyError as e:
        logger.error(f"Error extracting user from event: {e}")
        raise ValueError("Invalid authorization context")

def generate_file_id() -> str:
    """Generate a unique file ID"""
    return str(uuid.uuid4())

def generate_share_id() -> str:
    """Generate a unique share ID"""
    return str(uuid.uuid4())

def get_current_timestamp() -> str:
    """Get current timestamp in ISO format"""
    return datetime.utcnow().isoformat()

def get_expiration_timestamp(hours: int = 24) -> str:
    """Get expiration timestamp in ISO format"""
    return (datetime.utcnow() + timedelta(hours=hours)).isoformat()

def get_ttl_timestamp(hours: int = 24) -> int:
    """Get TTL timestamp for DynamoDB"""
    return int((datetime.utcnow() + timedelta(hours=hours)).timestamp())

def validate_file_permissions(user_role: str, operation: str, file_owner: str, user_id: str) -> bool:
    """Validate if user has permission to perform operation on file"""
    
    # Admin can do everything
    if user_role == 'admin':
        return True
    
    # Owner can do everything with their files
    if file_owner == user_id:
        return True
    
    # Editor can read shared files
    if user_role == 'editor' and operation in ['read', 'download']:
        return True
    
    # Viewer can only read shared files
    if user_role == 'viewer' and operation in ['read', 'download']:
        return True
    
    return False

def get_s3_client():
    """Get S3 client"""
    return boto3.client('s3')

def get_dynamodb_resource():
    """Get DynamoDB resource"""
    return boto3.resource('dynamodb')

def sanitize_filename(filename: str) -> str:
    """Sanitize filename for safe storage"""
    import re
    # Remove or replace unsafe characters
    filename = re.sub(r'[^\w\-_\.]', '_', filename)
    # Limit length
    if len(filename) > 255:
        name, ext = filename.rsplit('.', 1) if '.' in filename else (filename, '')
        filename = name[:250] + ('.' + ext if ext else '')
    return filename

def get_file_size_mb(size_bytes: int) -> int:
    """Convert bytes to MB (rounded)"""
    return round(size_bytes / (1024 * 1024))

def validate_file_size(size_bytes: int, max_size_mb: int = 5120) -> bool:
    """Validate file size (default max 5GB)"""
    max_size_bytes = max_size_mb * 1024 * 1024
    return size_bytes <= max_size_bytes

def get_content_type(filename: str) -> str:
    """Get content type based on file extension"""
    import mimetypes
    content_type, _ = mimetypes.guess_type(filename)
    return content_type or 'application/octet-stream'

class FileStorageError(Exception):
    """Custom exception for file storage operations"""
    pass

class PermissionError(Exception):
    """Custom exception for permission violations"""
    pass
