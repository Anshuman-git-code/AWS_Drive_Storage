import json
import os
import boto3
from botocore.exceptions import ClientError
import sys
sys.path.append('/opt/python')
from shared.utils import (
    create_response, get_user_from_event, validate_file_permissions,
    get_current_timestamp, FileStorageError, PermissionError
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
    Handle file deletion requests
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
        
        # Check if file is already deleted
        if file_metadata.get('status') == 'deleted':
            return create_response(404, {'error': 'File not found or has been deleted'})
        
        # Validate permissions - only owner or admin can delete
        if not (user['userId'] == file_metadata['userId'] or user['role'] == 'admin'):
            return create_response(403, {'error': 'Insufficient permissions to delete this file'})
        
        # Parse request body for deletion options
        body = {}
        if event.get('body'):
            try:
                body = json.loads(event['body'])
            except json.JSONDecodeError:
                pass
        
        permanent_delete = body.get('permanent', False)
        
        if permanent_delete and user['role'] != 'admin':
            return create_response(403, {'error': 'Only administrators can permanently delete files'})
        
        timestamp = get_current_timestamp()
        
        if permanent_delete:
            # Permanently delete file from S3
            try:
                s3_client.delete_object(
                    Bucket=FILE_STORAGE_BUCKET,
                    Key=file_metadata['s3Key']
                )
            except ClientError as e:
                print(f"Error deleting file from S3: {e}")
                return create_response(500, {'error': 'Error deleting file from storage'})
            
            # Remove metadata from DynamoDB
            try:
                metadata_table.delete_item(Key={'fileId': file_id})
            except ClientError as e:
                print(f"Error deleting file metadata: {e}")
                return create_response(500, {'error': 'Error removing file metadata'})
            
            return create_response(200, {
                'message': 'File permanently deleted',
                'fileId': file_id,
                'filename': file_metadata['filename'],
                'deletedAt': timestamp
            })
        
        else:
            # Soft delete - mark as deleted in metadata
            try:
                metadata_table.update_item(
                    Key={'fileId': file_id},
                    UpdateExpression='SET #status = :status, deletedAt = :deletedAt, lastModified = :lastModified',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={
                        ':status': 'deleted',
                        ':deletedAt': timestamp,
                        ':lastModified': timestamp
                    }
                )
            except ClientError as e:
                print(f"Error updating file metadata: {e}")
                return create_response(500, {'error': 'Error marking file as deleted'})
            
            return create_response(200, {
                'message': 'File deleted successfully',
                'fileId': file_id,
                'filename': file_metadata['filename'],
                'deletedAt': timestamp,
                'note': 'File has been moved to trash. Contact administrator for permanent deletion.'
            })
        
    except ValueError as e:
        return create_response(401, {'error': str(e)})
    except PermissionError as e:
        return create_response(403, {'error': str(e)})
    except Exception as e:
        print(f"Error deleting file: {str(e)}")
        return create_response(500, {
            'error': 'Internal server error occurred while deleting file'
        })
