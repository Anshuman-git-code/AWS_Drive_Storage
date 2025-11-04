import json
import os
import boto3
from botocore.exceptions import ClientError
import sys
sys.path.append('/opt/python')
from shared.utils import (
    create_response, get_user_from_event, validate_file_permissions,
    generate_share_id, get_current_timestamp, get_ttl_timestamp,
    FileStorageError, PermissionError
)

# Environment variables
FILE_STORAGE_BUCKET = os.environ['FILE_STORAGE_BUCKET']
FILE_METADATA_TABLE = os.environ['FILE_METADATA_TABLE']
SHARED_FILES_TABLE = os.environ['SHARED_FILES_TABLE']

# AWS clients
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
metadata_table = dynamodb.Table(FILE_METADATA_TABLE)
shared_files_table = dynamodb.Table(SHARED_FILES_TABLE)

def handler(event, context):
    """
    Handle file sharing requests
    """
    try:
        # Get user information
        user = get_user_from_event(event)
        
        # Get file ID from path parameters
        file_id = event['pathParameters']['fileId']
        
        # Parse request body
        body = json.loads(event['body'])
        
        # Validate required fields
        expiration_hours = body.get('expirationHours', 24)
        password = body.get('password')
        allow_download = body.get('allowDownload', True)
        
        # Validate expiration hours
        if not isinstance(expiration_hours, int) or expiration_hours < 1 or expiration_hours > 168:  # Max 1 week
            return create_response(400, {
                'error': 'Expiration hours must be between 1 and 168 (1 week)'
            })
        
        # Get file metadata from DynamoDB
        try:
            response = metadata_table.get_item(Key={'fileId': file_id})
            if 'Item' not in response:
                return create_response(404, {'error': 'File not found'})
            
            file_metadata = response['Item']
        except ClientError as e:
            print(f"Error getting file metadata: {e}")
            return create_response(500, {'error': 'Error retrieving file metadata'})
        
        # Check if file is active
        if file_metadata.get('status') != 'active':
            return create_response(404, {'error': 'File not found or has been deleted'})
        
        # Validate permissions - allow file owner to share
        if file_metadata['userId'] != user['userId'] and user['role'] != 'admin':
            return create_response(403, {'error': 'Insufficient permissions to share this file'})
        
        # Generate share information
        share_id = generate_share_id()
        timestamp = get_current_timestamp()
        ttl_timestamp = get_ttl_timestamp(expiration_hours)
        
        # Create share record
        share_item = {
            'shareId': share_id,
            'fileId': file_id,
            'sharedBy': user['userId'],
            'sharedAt': timestamp,
            'expirationTime': ttl_timestamp,
            'expirationHours': expiration_hours,
            'allowDownload': allow_download,
            'accessCount': 0,
            'maxAccess': body.get('maxAccess'),
            'isActive': True
        }
        
        # Add password if provided
        if password:
            import hashlib
            share_item['passwordHash'] = hashlib.sha256(password.encode()).hexdigest()
        
        # Store share record in DynamoDB
        try:
            shared_files_table.put_item(Item=share_item)
        except ClientError as e:
            print(f"Error creating share record: {e}")
            return create_response(500, {'error': 'Error creating share link'})
        
        # Update file metadata to track sharing
        try:
            metadata_table.update_item(
                Key={'fileId': file_id},
                UpdateExpression='ADD shareCount :inc SET lastShared = :timestamp',
                ExpressionAttributeValues={
                    ':inc': 1,
                    ':timestamp': timestamp
                }
            )
        except ClientError as e:
            print(f"Error updating file share count: {e}")
            # Non-critical error, continue
        
        # Generate share URL - return shareId so frontend can build the URL
        # Frontend will use: window.location.origin + '/shared/' + shareId
        
        # Return share information
        return create_response(201, {
            'message': 'File shared successfully',
            'shareId': share_id,
            'fileId': file_id,
            'filename': file_metadata['filename'],
            'sharedAt': timestamp,
            'expiresAt': ttl_timestamp,
            'expirationHours': expiration_hours,
            'allowDownload': allow_download,
            'hasPassword': bool(password)
        })
        
    except ValueError as e:
        return create_response(401, {'error': str(e)})
    except json.JSONDecodeError:
        return create_response(400, {'error': 'Invalid JSON in request body'})
    except PermissionError as e:
        return create_response(403, {'error': str(e)})
    except Exception as e:
        print(f"Error sharing file: {str(e)}")
        return create_response(500, {
            'error': 'Internal server error occurred while sharing file'
        })
