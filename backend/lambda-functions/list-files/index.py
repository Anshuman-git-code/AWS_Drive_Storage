import json
import os
import boto3
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key
import sys
sys.path.append('/opt/python')
from shared.utils import create_response, get_user_from_event, decimal_default, convert_dynamodb_response

# Environment variables
FILE_METADATA_TABLE = os.environ['FILE_METADATA_TABLE']

# AWS clients
dynamodb = boto3.resource('dynamodb')
metadata_table = dynamodb.Table(FILE_METADATA_TABLE)

def handler(event, context):
    """
    Handle list files requests
    """
    try:
        # Get user information
        user = get_user_from_event(event)
        
        # Get query parameters
        query_params = event.get('queryStringParameters') or {}
        limit = int(query_params.get('limit', 50))
        last_key = query_params.get('lastKey')
        search_term = query_params.get('search', '').lower()
        file_type = query_params.get('type')
        
        # Build query parameters
        query_kwargs = {
            'IndexName': 'UserFilesIndex',
            'KeyConditionExpression': Key('userId').eq(user['userId']),
            'ScanIndexForward': False,  # Sort by upload date descending
            'Limit': min(limit, 100)  # Cap at 100 items
        }
        
        # Add pagination
        if last_key:
            try:
                query_kwargs['ExclusiveStartKey'] = json.loads(last_key)
            except json.JSONDecodeError:
                return create_response(400, {'error': 'Invalid lastKey parameter'})
        
        # Query files
        try:
            response = metadata_table.query(**query_kwargs)
            files = convert_dynamodb_response(response.get('Items', []))
        except ClientError as e:
            print(f"Error querying files: {e}")
            return create_response(500, {'error': 'Error retrieving files'})
        
        # Filter files
        filtered_files = []
        for file_item in files:
            # Skip inactive files
            if file_item.get('status') != 'active':
                continue
            
            # Apply search filter
            if search_term:
                filename_lower = file_item.get('filename', '').lower()
                description_lower = file_item.get('description', '').lower()
                tags_lower = ' '.join(file_item.get('tags', [])).lower()
                
                if not (search_term in filename_lower or 
                       search_term in description_lower or 
                       search_term in tags_lower):
                    continue
            
            # Apply file type filter
            if file_type:
                content_type = file_item.get('contentType', '')
                if not content_type.startswith(file_type):
                    continue
            
            # Prepare file info for response
            file_info = {
                'fileId': file_item['fileId'],
                'filename': file_item['filename'],
                'fileSize': file_item['fileSize'],
                'fileSizeMB': file_item.get('fileSizeMB', 0),
                'contentType': file_item['contentType'],
                'uploadDate': file_item['uploadDate'],
                'lastModified': file_item.get('lastModified', file_item['uploadDate']),
                'tags': file_item.get('tags', []),
                'description': file_item.get('description', ''),
                'isPublic': file_item.get('isPublic', False),
                'version': file_item.get('version', 1)
            }
            
            filtered_files.append(file_info)
        
        # Prepare response
        response_data = {
            'files': filtered_files,
            'count': len(filtered_files),
            'hasMore': 'LastEvaluatedKey' in response
        }
        
        # Add pagination info
        if 'LastEvaluatedKey' in response:
            response_data['lastKey'] = json.dumps(response['LastEvaluatedKey'], default=decimal_default)
        
        # Add summary statistics
        if user['role'] == 'admin':
            try:
                # Get total file count and size for admin users
                scan_response = metadata_table.scan(
                    FilterExpression='userId = :userId AND #status = :status',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={
                        ':userId': user['userId'],
                        ':status': 'active'
                    },
                    Select='COUNT'
                )
                
                response_data['totalFiles'] = scan_response['Count']
            except ClientError:
                # If scan fails, don't include total count
                pass
        
        return create_response(200, response_data)
        
    except ValueError as e:
        return create_response(401, {'error': str(e)})
    except Exception as e:
        print(f"Error listing files: {str(e)}")
        return create_response(500, {
            'error': 'Internal server error occurred while listing files'
        })
