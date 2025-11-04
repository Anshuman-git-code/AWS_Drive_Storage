import json
import os
import boto3
from botocore.exceptions import ClientError
import sys
sys.path.append('/opt/python')
from shared.utils import (
    create_response, get_user_from_event, validate_file_permissions,
    FileStorageError, PermissionError
)

# Environment variables
FILE_STORAGE_BUCKET = os.environ['FILE_STORAGE_BUCKET']
FILE_METADATA_TABLE = os.environ['FILE_METADATA_TABLE']

# AWS clients
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
metadata_table = dynamodb.Table(FILE_METADATA_TABLE)

def handler(event, context):
    """
    Handle file download requests - generates pre-signed URL
    """
    try:
        # Get user information
        user = get_user_from_event(event)
        
        # Get file ID from path parameters
        file_id = event['pathParameters']['fileId']
        
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
        
        # Validate permissions
        if not validate_file_permissions(
            user['role'], 
            'download', 
            file_metadata['userId'], 
            user['userId']
        ):
            return create_response(403, {'error': 'Insufficient permissions to download this file'})
        
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
        
        # Return download information
        return create_response(200, {
            'downloadUrl': presigned_url,
            'filename': file_metadata['filename'],
            'fileSize': file_metadata['fileSize'],
            'contentType': file_metadata['contentType'],
            'expiresIn': 3600,
            'fileId': file_id
        })
        
    except ValueError as e:
        return create_response(401, {'error': str(e)})
    except PermissionError as e:
        return create_response(403, {'error': str(e)})
    except Exception as e:
        print(f"Error downloading file: {str(e)}")
        return create_response(500, {
            'error': 'Internal server error occurred while processing download request'
        })
