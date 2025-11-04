import json
import os
import boto3
import base64
from datetime import datetime
import sys
sys.path.append('/opt/python')
from shared.utils import (
    create_response, get_user_from_event, generate_file_id, 
    get_current_timestamp, sanitize_filename, get_file_size_mb,
    validate_file_size, get_content_type, FileStorageError
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
    Handle file upload requests
    """
    try:
        # Get user information
        user = get_user_from_event(event)
        
        # Parse request body
        body = json.loads(event['body'])
        
        # Validate required fields
        if 'filename' not in body or 'content' not in body:
            return create_response(400, {
                'error': 'Missing required fields: filename and content'
            })
        
        filename = sanitize_filename(body['filename'])
        file_content = base64.b64decode(body['content'])
        file_size = len(file_content)
        
        # Validate file size
        if not validate_file_size(file_size):
            return create_response(400, {
                'error': f'File size ({get_file_size_mb(file_size)} MB) exceeds maximum allowed size (5GB)'
            })
        
        # Generate file metadata
        file_id = generate_file_id()
        timestamp = get_current_timestamp()
        content_type = get_content_type(filename)
        
        # Create S3 key
        s3_key = f"users/{user['userId']}/files/{file_id}/{filename}"
        
        # Upload file to S3
        s3_client.put_object(
            Bucket=FILE_STORAGE_BUCKET,
            Key=s3_key,
            Body=file_content,
            ContentType=content_type,
            Metadata={
                'original-filename': filename,
                'uploaded-by': user['userId'],
                'upload-timestamp': timestamp
            }
        )
        
        # Store metadata in DynamoDB
        metadata_item = {
            'fileId': file_id,
            'userId': user['userId'],
            'filename': filename,
            'originalFilename': filename,
            's3Key': s3_key,
            'contentType': content_type,
            'fileSize': file_size,
            'fileSizeMB': get_file_size_mb(file_size),
            'uploadDate': timestamp,
            'lastModified': timestamp,
            'tags': body.get('tags', []),
            'description': body.get('description', ''),
            'isPublic': body.get('isPublic', False),
            'version': 1,
            'status': 'active'
        }
        
        metadata_table.put_item(Item=metadata_item)
        
        # Return success response
        return create_response(201, {
            'message': 'File uploaded successfully',
            'fileId': file_id,
            'filename': filename,
            'fileSize': file_size,
            'fileSizeMB': get_file_size_mb(file_size),
            'uploadDate': timestamp
        })
        
    except ValueError as e:
        return create_response(401, {'error': str(e)})
    except FileStorageError as e:
        return create_response(400, {'error': str(e)})
    except Exception as e:
        print(f"Error uploading file: {str(e)}")
        return create_response(500, {
            'error': 'Internal server error occurred while uploading file'
        })
