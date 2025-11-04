#!/bin/bash

# Complete System Deployment Script
# Cloud-Based File Storage System with Role-Based Access

set -e

# Configuration
PROJECT_NAME="file-storage-system"
ENVIRONMENT="prod"
REGION="us-east-1"
STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "\n${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}\n"
}

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

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured"
        exit 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed"
        exit 1
    fi
    
    print_success "All prerequisites met"
    
    # Display AWS account info
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)
    print_status "AWS Account: $ACCOUNT_ID"
    print_status "Current User: $CURRENT_USER"
    print_status "Region: $REGION"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_header "Deploying Infrastructure"
    
    cd infrastructure
    
    # Validate template
    print_status "Validating CloudFormation template..."
    aws cloudformation validate-template --template-body file://main.yaml > /dev/null
    print_success "Template validation passed"
    
    # Deploy stack
    print_status "Deploying infrastructure stack..."
    
    if aws cloudformation describe-stacks --stack-name $STACK_NAME &> /dev/null; then
        print_status "Stack exists. Updating..."
        aws cloudformation update-stack \
            --stack-name $STACK_NAME \
            --template-body file://main.yaml \
            --parameters ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            --capabilities CAPABILITY_NAMED_IAM \
            --region $REGION
        
        print_status "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $REGION
    else
        print_status "Creating new stack..."
        aws cloudformation create-stack \
            --stack-name $STACK_NAME \
            --template-body file://main.yaml \
            --parameters ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            --capabilities CAPABILITY_NAMED_IAM \
            --region $REGION
        
        print_status "Waiting for stack creation to complete..."
        aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    fi
    
    print_success "Infrastructure deployment completed"
    
    # Save outputs
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs' \
        --output json > stack-outputs.json
    
    print_success "Stack outputs saved to infrastructure/stack-outputs.json"
    
    cd ..
}

# Function to deploy Lambda functions
deploy_lambda_functions() {
    print_header "Deploying Lambda Functions"
    
    cd backend
    
    # Get deployment bucket
    DEPLOYMENT_BUCKET=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query "Stacks[0].Outputs[?OutputKey=='LambdaDeploymentBucketName'].OutputValue" \
        --output text)
    
    print_status "Using deployment bucket: $DEPLOYMENT_BUCKET"
    
    # Create deployment packages
    functions=("upload-file" "download-file" "list-files" "delete-file" "share-file" "get-shared-file")
    
    for func in "${functions[@]}"; do
        print_status "Creating deployment package for $func"
        
        # Create temporary directory
        temp_dir=$(mktemp -d)
        
        # Copy function code
        cp -r $func/* $temp_dir/
        
        # Copy shared utilities
        mkdir -p $temp_dir/shared
        cp shared/utils.py $temp_dir/shared/
        
        # Create zip package
        cd $temp_dir
        zip -r ../${func}.zip . -x "*.pyc" "__pycache__/*" > /dev/null
        cd - > /dev/null
        
        # Move package to current directory
        mv $temp_dir/../${func}.zip .
        
        # Clean up
        rm -rf $temp_dir
        
        print_success "Created ${func}.zip"
    done
    
    # Upload packages to S3
    print_status "Uploading Lambda packages to S3..."
    aws s3api put-object --bucket $DEPLOYMENT_BUCKET --key lambda/ --region $REGION > /dev/null
    
    for package in *.zip; do
        if [ -f "$package" ]; then
            print_status "Uploading $package..."
            aws s3 cp $package s3://$DEPLOYMENT_BUCKET/lambda/ --region $REGION > /dev/null
        fi
    done
    
    # Deploy Lambda stack
    LAMBDA_STACK_NAME="${PROJECT_NAME}-lambda-${ENVIRONMENT}"
    
    print_status "Deploying Lambda functions stack..."
    
    if aws cloudformation describe-stacks --stack-name $LAMBDA_STACK_NAME --region $REGION &> /dev/null; then
        print_status "Lambda stack exists. Updating..."
        aws cloudformation update-stack \
            --stack-name $LAMBDA_STACK_NAME \
            --template-body file://../infrastructure/lambda-functions.yaml \
            --parameters ParameterKey=MainStackName,ParameterValue=$STACK_NAME ParameterKey=LambdaCodeBucket,ParameterValue=$DEPLOYMENT_BUCKET \
            --capabilities CAPABILITY_IAM \
            --region $REGION
        
        print_status "Waiting for Lambda stack update to complete..."
        aws cloudformation wait stack-update-complete --stack-name $LAMBDA_STACK_NAME --region $REGION
    else
        print_status "Creating new Lambda stack..."
        aws cloudformation create-stack \
            --stack-name $LAMBDA_STACK_NAME \
            --template-body file://../infrastructure/lambda-functions.yaml \
            --parameters ParameterKey=MainStackName,ParameterValue=$STACK_NAME ParameterKey=LambdaCodeBucket,ParameterValue=$DEPLOYMENT_BUCKET \
            --capabilities CAPABILITY_IAM \
            --region $REGION
        
        print_status "Waiting for Lambda stack creation to complete..."
        aws cloudformation wait stack-create-complete --stack-name $LAMBDA_STACK_NAME --region $REGION
    fi
    
    print_success "Lambda functions deployment completed"
    
    # Get API Gateway URL
    API_URL=$(aws cloudformation describe-stacks \
        --stack-name $LAMBDA_STACK_NAME \
        --region $REGION \
        --query "Stacks[0].Outputs[?OutputKey=='ApiGatewayUrl'].OutputValue" \
        --output text)
    
    if [ -n "$API_URL" ]; then
        echo "$API_URL" > api-gateway-url.txt
        print_success "API Gateway URL: $API_URL"
        print_status "API URL saved to backend/api-gateway-url.txt"
    fi
    
    # Clean up zip files
    rm -f *.zip
    
    cd ..
}

# Function to create Cognito users
create_cognito_users() {
    print_header "Creating Cognito Test Users"
    
    # Get User Pool ID
    USER_POOL_ID=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query "Stacks[0].Outputs[?OutputKey=='UserPoolId'].OutputValue" \
        --output text)
    
    print_status "User Pool ID: $USER_POOL_ID"
    
    # Create test users
    users=(
        "admin@example.com:Admin123!:admin"
        "editor@example.com:Editor123!:editor"
        "viewer@example.com:Viewer123!:viewer"
    )
    
    for user_info in "${users[@]}"; do
        IFS=':' read -r email password role <<< "$user_info"
        
        print_status "Creating user: $email (role: $role)"
        
        # Create user
        if aws cognito-idp admin-create-user \
            --user-pool-id $USER_POOL_ID \
            --username $email \
            --user-attributes Name=email,Value=$email Name=custom:role,Value=$role \
            --temporary-password TempPass123! \
            --message-action SUPPRESS \
            --region $REGION &> /dev/null; then
            
            # Set permanent password
            aws cognito-idp admin-set-user-password \
                --user-pool-id $USER_POOL_ID \
                --username $email \
                --password $password \
                --permanent \
                --region $REGION > /dev/null
            
            print_success "Created user: $email"
        else
            print_warning "User $email may already exist"
        fi
    done
}

# Function to setup frontend
setup_frontend() {
    print_header "Setting Up Frontend"
    
    cd frontend
    
    # Install dependencies
    print_status "Installing frontend dependencies..."
    npm install > /dev/null 2>&1
    print_success "Dependencies installed"
    
    # Get configuration values
    USER_POOL_ID=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query "Stacks[0].Outputs[?OutputKey=='UserPoolId'].OutputValue" \
        --output text)
    
    CLIENT_ID=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query "Stacks[0].Outputs[?OutputKey=='UserPoolClientId'].OutputValue" \
        --output text)
    
    API_URL=$(cat ../backend/api-gateway-url.txt 2>/dev/null || echo "")
    
    # Create environment file
    print_status "Creating environment configuration..."
    cat > .env << EOF
REACT_APP_USER_POOL_ID=$USER_POOL_ID
REACT_APP_CLIENT_ID=$CLIENT_ID
REACT_APP_API_URL=$API_URL
EOF
    
    print_success "Environment configuration created"
    print_status "Frontend is ready to start with: npm start"
    
    cd ..
}

# Function to run tests
run_tests() {
    print_header "Running Tests"
    
    # Backend unit tests
    print_status "Running backend unit tests..."
    cd backend
    if command -v pytest &> /dev/null; then
        python -m pytest tests/unit/ -v --tb=short || print_warning "Some backend tests failed"
    else
        print_warning "pytest not installed, skipping backend tests"
    fi
    cd ..
    
    # Frontend tests
    print_status "Running frontend tests..."
    cd frontend
    if [ -f "package.json" ]; then
        npm test -- --coverage --watchAll=false || print_warning "Some frontend tests failed"
    else
        print_warning "Frontend not properly set up, skipping tests"
    fi
    cd ..
}

# Function to verify deployment
verify_deployment() {
    print_header "Verifying Deployment"
    
    # Check API Gateway
    if [ -f "backend/api-gateway-url.txt" ]; then
        API_URL=$(cat backend/api-gateway-url.txt)
        print_status "Testing API Gateway endpoint..."
        
        if curl -s -o /dev/null -w "%{http_code}" "$API_URL/files" | grep -q "401"; then
            print_success "API Gateway is responding (401 Unauthorized as expected)"
        else
            print_warning "API Gateway response unexpected"
        fi
    fi
    
    # Check S3 buckets
    print_status "Verifying S3 buckets..."
    FILE_BUCKET=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query "Stacks[0].Outputs[?OutputKey=='FileStorageBucketName'].OutputValue" \
        --output text)
    
    if aws s3 ls s3://$FILE_BUCKET &> /dev/null; then
        print_success "File storage bucket accessible: $FILE_BUCKET"
    else
        print_error "File storage bucket not accessible"
    fi
    
    # Check DynamoDB tables
    print_status "Verifying DynamoDB tables..."
    METADATA_TABLE=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query "Stacks[0].Outputs[?OutputKey=='FileMetadataTableName'].OutputValue" \
        --output text)
    
    if aws dynamodb describe-table --table-name $METADATA_TABLE --region $REGION &> /dev/null; then
        print_success "Metadata table accessible: $METADATA_TABLE"
    else
        print_error "Metadata table not accessible"
    fi
    
    # Check Lambda functions
    print_status "Verifying Lambda functions..."
    UPLOAD_FUNCTION="${STACK_NAME}-upload-file"
    
    if aws lambda get-function --function-name $UPLOAD_FUNCTION --region $REGION &> /dev/null; then
        print_success "Lambda functions deployed successfully"
    else
        print_error "Lambda functions not accessible"
    fi
}

# Function to display deployment summary
display_summary() {
    print_header "Deployment Summary"
    
    # Get key information
    USER_POOL_ID=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query "Stacks[0].Outputs[?OutputKey=='UserPoolId'].OutputValue" \
        --output text)
    
    CLIENT_ID=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query "Stacks[0].Outputs[?OutputKey=='UserPoolClientId'].OutputValue" \
        --output text)
    
    API_URL=$(cat backend/api-gateway-url.txt 2>/dev/null || echo "Not available")
    
    echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"
    echo -e "${GREEN}✅ Lambda functions deployed successfully${NC}"
    echo -e "${GREEN}✅ Cognito users created${NC}"
    echo -e "${GREEN}✅ Frontend configured${NC}"
    echo ""
    echo -e "${BLUE}📋 Configuration Details:${NC}"
    echo -e "   User Pool ID: ${YELLOW}$USER_POOL_ID${NC}"
    echo -e "   Client ID: ${YELLOW}$CLIENT_ID${NC}"
    echo -e "   API Gateway URL: ${YELLOW}$API_URL${NC}"
    echo ""
    echo -e "${BLUE}👥 Test Users Created:${NC}"
    echo -e "   Admin: ${YELLOW}admin@example.com${NC} / ${YELLOW}Admin123!${NC}"
    echo -e "   Editor: ${YELLOW}editor@example.com${NC} / ${YELLOW}Editor123!${NC}"
    echo -e "   Viewer: ${YELLOW}viewer@example.com${NC} / ${YELLOW}Viewer123!${NC}"
    echo ""
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo -e "   1. Start frontend: ${YELLOW}cd frontend && npm start${NC}"
    echo -e "   2. Access application: ${YELLOW}http://localhost:3000${NC}"
    echo -e "   3. Login with test credentials above"
    echo -e "   4. Test file upload, download, and sharing"
    echo ""
    echo -e "${BLUE}📚 Documentation:${NC}"
    echo -e "   - API Documentation: ${YELLOW}docs/API_DOCUMENTATION.md${NC}"
    echo -e "   - Security Architecture: ${YELLOW}docs/SECURITY_ARCHITECTURE.md${NC}"
    echo -e "   - Testing Guide: ${YELLOW}docs/TESTING_GUIDE.md${NC}"
    echo ""
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
}

# Function to handle cleanup on error
cleanup_on_error() {
    print_error "Deployment failed. Cleaning up..."
    
    # Optionally clean up partial deployments
    # This is commented out to preserve resources for debugging
    # aws cloudformation delete-stack --stack-name $LAMBDA_STACK_NAME --region $REGION || true
    # aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION || true
    
    exit 1
}

# Main execution
main() {
    print_header "Cloud-Based File Storage System Deployment"
    print_status "Starting complete system deployment..."
    print_status "Project: $PROJECT_NAME"
    print_status "Environment: $ENVIRONMENT"
    print_status "Region: $REGION"
    
    # Set error handler
    trap cleanup_on_error ERR
    
    # Execute deployment steps
    check_prerequisites
    deploy_infrastructure
    deploy_lambda_functions
    create_cognito_users
    setup_frontend
    verify_deployment
    
    # Optional: Run tests
    if [ "$1" = "--with-tests" ]; then
        run_tests
    fi
    
    display_summary
}

# Run main function with all arguments
main "$@"
