#!/bin/bash

# Cloud-Based File Storage System - Lambda Functions Deployment Script

set -e

# Configuration
PROJECT_NAME="file-storage-system"
ENVIRONMENT="prod"
REGION="us-east-1"
MAIN_STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
LAMBDA_STACK_NAME="${PROJECT_NAME}-lambda-${ENVIRONMENT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get stack output value
get_stack_output() {
    local stack_name=$1
    local output_key=$2
    
    aws cloudformation describe-stacks \
        --stack-name $stack_name \
        --region $REGION \
        --query "Stacks[0].Outputs[?OutputKey=='$output_key'].OutputValue" \
        --output text
}

# Function to create deployment package
create_deployment_package() {
    local function_name=$1
    local package_name="${function_name}.zip"
    
    print_status "Creating deployment package for $function_name"
    
    # Create temporary directory
    temp_dir=$(mktemp -d)
    
    # Copy function code
    cp -r $function_name/* $temp_dir/
    
    # Copy shared utilities
    mkdir -p $temp_dir/shared
    cp shared/utils.py $temp_dir/shared/
    
    # Create package.json for shared dependencies
    cat > $temp_dir/shared/package.json << EOF
{
  "name": "shared-utils",
  "version": "1.0.0",
  "description": "Shared utilities for Lambda functions"
}
EOF
    
    # Create zip package
    cd $temp_dir
    zip -r ../$package_name . -x "*.pyc" "__pycache__/*"
    cd - > /dev/null
    
    # Move package to current directory
    mv $temp_dir/../$package_name .
    
    # Clean up
    rm -rf $temp_dir
    
    print_success "Created deployment package: $package_name"
}

# Function to upload packages to S3
upload_packages() {
    local bucket_name=$1
    
    print_status "Uploading Lambda packages to S3 bucket: $bucket_name"
    
    # Create lambda directory in S3 if it doesn't exist
    aws s3api put-object --bucket $bucket_name --key lambda/ --region $REGION
    
    # Upload each package
    for package in *.zip; do
        if [ -f "$package" ]; then
            print_status "Uploading $package..."
            aws s3 cp $package s3://$bucket_name/lambda/ --region $REGION
            print_success "Uploaded $package"
        fi
    done
}

# Function to deploy Lambda stack
deploy_lambda_stack() {
    local bucket_name=$1
    
    print_status "Deploying Lambda functions stack"
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name $LAMBDA_STACK_NAME --region $REGION &> /dev/null; then
        print_status "Stack exists. Updating..."
        aws cloudformation update-stack \
            --stack-name $LAMBDA_STACK_NAME \
            --template-body file://../infrastructure/lambda-functions.yaml \
            --parameters ParameterKey=MainStackName,ParameterValue=$MAIN_STACK_NAME ParameterKey=LambdaCodeBucket,ParameterValue=$bucket_name \
            --capabilities CAPABILITY_IAM \
            --region $REGION
        
        print_status "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete --stack-name $LAMBDA_STACK_NAME --region $REGION
    else
        print_status "Creating new stack..."
        aws cloudformation create-stack \
            --stack-name $LAMBDA_STACK_NAME \
            --template-body file://../infrastructure/lambda-functions.yaml \
            --parameters ParameterKey=MainStackName,ParameterValue=$MAIN_STACK_NAME ParameterKey=LambdaCodeBucket,ParameterValue=$bucket_name \
            --capabilities CAPABILITY_IAM \
            --region $REGION
        
        print_status "Waiting for stack creation to complete..."
        aws cloudformation wait stack-create-complete --stack-name $LAMBDA_STACK_NAME --region $REGION
    fi
    
    print_success "Lambda stack deployment completed"
}

# Function to test Lambda functions
test_functions() {
    print_status "Testing Lambda functions..."
    
    # List of functions to test
    functions=(
        "${MAIN_STACK_NAME}-upload-file"
        "${MAIN_STACK_NAME}-download-file"
        "${MAIN_STACK_NAME}-list-files"
        "${MAIN_STACK_NAME}-delete-file"
        "${MAIN_STACK_NAME}-share-file"
        "${MAIN_STACK_NAME}-get-shared-file"
    )
    
    for func in "${functions[@]}"; do
        print_status "Testing function: $func"
        
        # Create a simple test event
        test_event='{"httpMethod": "GET", "pathParameters": {}, "queryStringParameters": {}, "requestContext": {"authorizer": {"claims": {"sub": "test-user", "email": "test@example.com", "custom:role": "admin"}}}}'
        
        # Invoke function (this will likely fail due to missing data, but confirms function exists)
        if aws lambda invoke --function-name $func --payload "$test_event" --region $REGION /tmp/response.json &> /dev/null; then
            print_success "Function $func is accessible"
        else
            print_warning "Function $func test failed (expected for some functions without proper test data)"
        fi
    done
}

# Main deployment function
main() {
    print_status "Starting Lambda functions deployment"
    print_status "Project: $PROJECT_NAME"
    print_status "Environment: $ENVIRONMENT"
    print_status "Region: $REGION"
    
    # Check if main stack exists
    if ! aws cloudformation describe-stacks --stack-name $MAIN_STACK_NAME --region $REGION &> /dev/null; then
        print_error "Main infrastructure stack not found. Please deploy infrastructure first."
        exit 1
    fi
    
    # Get deployment bucket name
    DEPLOYMENT_BUCKET=$(get_stack_output $MAIN_STACK_NAME "LambdaDeploymentBucketName")
    if [ -z "$DEPLOYMENT_BUCKET" ]; then
        print_error "Could not retrieve deployment bucket name from main stack"
        exit 1
    fi
    
    print_status "Using deployment bucket: $DEPLOYMENT_BUCKET"
    
    # Create deployment packages
    functions=(
        "upload-file"
        "download-file"
        "list-files"
        "delete-file"
        "share-file"
        "get-shared-file"
    )
    
    for func in "${functions[@]}"; do
        if [ -d "$func" ]; then
            create_deployment_package $func
        else
            print_error "Function directory not found: $func"
            exit 1
        fi
    done
    
    # Upload packages to S3
    upload_packages $DEPLOYMENT_BUCKET
    
    # Deploy Lambda stack
    deploy_lambda_stack $DEPLOYMENT_BUCKET
    
    # Test functions
    test_functions
    
    # Get API Gateway URL
    API_URL=$(get_stack_output $LAMBDA_STACK_NAME "ApiGatewayUrl")
    if [ -n "$API_URL" ]; then
        print_success "API Gateway URL: $API_URL"
        echo "$API_URL" > api-gateway-url.txt
        print_status "API URL saved to api-gateway-url.txt"
    fi
    
    # Clean up zip files
    rm -f *.zip
    
    print_success "Lambda functions deployment completed successfully!"
    
    print_status "Next steps:"
    echo "1. Test the API endpoints using the API Gateway URL"
    echo "2. Set up the frontend application"
    echo "3. Create Cognito users for testing"
}

# Run main function
main "$@"
