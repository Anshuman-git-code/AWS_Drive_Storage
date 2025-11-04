import json
import os
import boto3
from botocore.exceptions import ClientError
from datetime import datetime
import sys
sys.path.append('/opt/python')
from shared.utils import create_response, FileStorageError

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
    Handle shared file access requests
    """
    try:
        # Get share ID from path parameters
        share_id = event['pathParameters']['shareId']
        
        # Parse query parameters
        query_params = event.get('queryStringParameters') or {}
        password = query_params.get('password')
        action = query_params.get('action', 'view')  # 'view' or 'download'
        
        # Get share record from DynamoDB
        try:
            response = shared_files_table.get_item(Key={'shareId': share_id})
            if 'Item' not in response:
                return create_response(404, {'error': 'Share link not found or has expired'})
            
            share_record = response['Item']
        except ClientError as e:
            print(f"Error getting share record: {e}")
            return create_response(500, {'error': 'Error retrieving share information'})
        
        # Check if share is active
        if not share_record.get('isActive', True):
            return create_response(404, {'error': 'Share link has been deactivated'})
        
        # Check expiration
        current_timestamp = int(datetime.utcnow().timestamp())
        if current_timestamp > share_record['expirationTime']:
            return create_response(410, {'error': 'Share link has expired'})
        
        # Check access count limit
        max_access = share_record.get('maxAccess')
        if max_access and share_record.get('accessCount', 0) >= max_access:
            return create_response(429, {'error': 'Share link has reached maximum access limit'})
        
        # Check password if required
        if 'passwordHash' in share_record:
            if not password:
                return create_response(401, {
                    'error': 'Password required',
                    'requiresPassword': True
                })
            
            import hashlib
            provided_hash = hashlib.sha256(password.encode()).hexdigest()
            if provided_hash != share_record['passwordHash']:
                return create_response(401, {'error': 'Invalid password'})
        
        # Get file metadata
        file_id = share_record['fileId']
        try:
            response = metadata_table.get_item(Key={'fileId': file_id})
            if 'Item' not in response:
                return create_response(404, {'error': 'Original file not found'})
            
            file_metadata = response['Item']
        except ClientError as e:
            print(f"Error getting file metadata: {e}")
            return create_response(500, {'error': 'Error retrieving file information'})
        
        # Check if original file is still active
        if file_metadata.get('status') != 'active':
            return create_response(404, {'error': 'Original file has been deleted'})
        
        # Check download permission
        if action == 'download' and not share_record.get('allowDownload', True):
            return create_response(403, {'error': 'Download not allowed for this share'})
        
        # Update access count
        try:
            shared_files_table.update_item(
                Key={'shareId': share_id},
                UpdateExpression='ADD accessCount :inc SET lastAccessed = :timestamp',
                ExpressionAttributeValues={
                    ':inc': 1,
                    ':timestamp': datetime.utcnow().isoformat()
                }
            )
        except ClientError as e:
            print(f"Error updating access count: {e}")
            # Non-critical error, continue
        
        # Prepare response based on action
        if action == 'download':
            # Generate pre-signed URL for download
            try:
                presigned_url = s3_client.generate_presigned_url(
                    'get_object',
                    Params={
                        'Bucket': FILE_STORAGE_BUCKET,
                        'Key': file_metadata['s3Key']
                    },
                    ExpiresIn=3600  # 1 hour
                )
            except ClientError as e:
                print(f"Error generating pre-signed URL: {e}")
                return create_response(500, {'error': 'Error generating download URL'})
            
            return create_response(200, {
                'downloadUrl': presigned_url,
                'filename': file_metadata['filename'],
                'fileSize': file_metadata['fileSize'],
                'contentType': file_metadata['contentType'],
                'expiresIn': 3600
            })
        
        else:
            # Generate pre-signed URL for download
            try:
                presigned_url = s3_client.generate_presigned_url(
                    'get_object',
                    Params={
                        'Bucket': FILE_STORAGE_BUCKET,
                        'Key': file_metadata['s3Key']
                    },
                    ExpiresIn=3600  # 1 hour
                )
            except ClientError as e:
                print(f"Error generating pre-signed URL: {e}")
                presigned_url = None
            
            # Return file information for viewing
            return create_response(200, {
                'fileInfo': {
                    'filename': file_metadata['filename'],
                    'fileSize': file_metadata['fileSize'],
                    'fileSizeMB': file_metadata.get('fileSizeMB', 0),
                    'contentType': file_metadata['contentType'],
                    'uploadDate': file_metadata['uploadDate'],
                    'description': file_metadata.get('description', ''),
                    'tags': file_metadata.get('tags', [])
                },
                'shareInfo': {
                    'sharedBy': share_record['sharedBy'],
                    'sharedAt': share_record['sharedAt'],
                    'expiresAt': share_record['expirationTime'],
                    'allowDownload': share_record.get('allowDownload', True),
                    'accessCount': share_record.get('accessCount', 0) + 1,
                    'maxAccess': share_record.get('maxAccess')
                },
                'downloadUrl': presigned_url
            })
        
    except Exception as e:
        print(f"Error accessing shared file: {str(e)}")
        return create_response(500, {
            'error': 'Internal server error occurred while accessing shared file'
        })
