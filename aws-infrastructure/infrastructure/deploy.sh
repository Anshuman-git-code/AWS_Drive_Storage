#!/bin/bash

# Cloud-Based File Storage System - Infrastructure Deployment Script

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

# Function to check if AWS CLI is configured
check_aws_cli() {
    print_status "Checking AWS CLI configuration..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS CLI is configured"
}

# Function to validate CloudFormation template
validate_template() {
    local template_file=$1
    print_status "Validating CloudFormation template: $template_file"
    
    if aws cloudformation validate-template --template-body file://$template_file &> /dev/null; then
        print_success "Template validation passed: $template_file"
    else
        print_error "Template validation failed: $template_file"
        exit 1
    fi
}

# Function to deploy CloudFormation stack
deploy_stack() {
    local template_file=$1
    local stack_name=$2
    local parameters=$3
    
    print_status "Deploying stack: $stack_name"
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name $stack_name &> /dev/null; then
        print_status "Stack exists. Updating..."
        aws cloudformation update-stack \
            --stack-name $stack_name \
            --template-body file://$template_file \
            --parameters $parameters \
            --capabilities CAPABILITY_NAMED_IAM \
            --region $REGION
        
        print_status "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete --stack-name $stack_name --region $REGION
    else
        print_status "Creating new stack..."
        aws cloudformation create-stack \
            --stack-name $stack_name \
            --template-body file://$template_file \
            --parameters $parameters \
            --capabilities CAPABILITY_NAMED_IAM \
            --region $REGION
        
        print_status "Waiting for stack creation to complete..."
        aws cloudformation wait stack-create-complete --stack-name $stack_name --region $REGION
    fi
    
    print_success "Stack deployment completed: $stack_name"
}

# Function to get stack outputs
get_stack_outputs() {
    local stack_name=$1
    print_status "Retrieving stack outputs for: $stack_name"
    
    aws cloudformation describe-stacks \
        --stack-name $stack_name \
        --region $REGION \
        --query 'Stacks[0].Outputs' \
        --output table
}

# Main deployment function
main() {
    print_status "Starting deployment of Cloud-Based File Storage System"
    print_status "Project: $PROJECT_NAME"
    print_status "Environment: $ENVIRONMENT"
    print_status "Region: $REGION"
    
    # Check prerequisites
    check_aws_cli
    
    # Validate templates
    validate_template "main.yaml"
    
    # Deploy main infrastructure stack
    deploy_stack "main.yaml" "$STACK_NAME" "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME ParameterKey=Environment,ParameterValue=$ENVIRONMENT"
    
    # Get and display outputs
    print_success "Infrastructure deployment completed successfully!"
    print_status "Stack outputs:"
    get_stack_outputs "$STACK_NAME"
    
    # Save outputs to file for later use
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs' \
        --output json > stack-outputs.json
    
    print_success "Stack outputs saved to stack-outputs.json"
    
    print_status "Next steps:"
    echo "1. Deploy Lambda functions: cd ../backend && ./deploy-functions.sh"
    echo "2. Set up frontend: cd ../frontend && npm install && npm start"
    echo "3. Create Cognito users and configure roles"
}

# Run main function
main "$@"
