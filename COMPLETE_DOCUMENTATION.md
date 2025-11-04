# Cloud File Storage System - Complete Documentation

## 📋 Table of Contents
1. [System Overview](#system-overview)
2. [Architecture & File Dependencies](#architecture--file-dependencies)
3. [Features](#features)
4. [Prerequisites](#prerequisites)
5. [Deployment Guide](#deployment-guide)
6. [Usage Guide](#usage-guide)
7. [File Structure](#file-structure)
8. [API Endpoints](#api-endpoints)
9. [Troubleshooting](#troubleshooting)

---

## 🏗️ System Overview

**Cloud File Storage System** is a production-ready, serverless file storage application built on AWS. It provides secure file upload, download, sharing, and management capabilities with user authentication.

### Technology Stack
- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **Backend**: AWS Lambda (Python 3.9)
- **Database**: Amazon DynamoDB
- **Storage**: Amazon S3
- **Authentication**: Amazon Cognito
- **API**: Amazon API Gateway
- **Infrastructure**: AWS CloudFormation

---

## 🔗 Architecture & File Dependencies

### System Architecture
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │───▶│   API Gateway    │───▶│  Lambda Functions│
│  (index.html)   │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │   Cognito        │    │      S3         │
                       │ (Authentication) │    │ (File Storage)  │
                       └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │   DynamoDB      │
                                               │  (Metadata)     │
                                               └─────────────────┘
```

### File Dependencies Map

#### **Frontend Layer**
```
frontend/
├── index.html          # Main UI → Cognito SDK → API Gateway
├── shared.html         # Shared files viewer → API Gateway  
└── start.sh           # Server startup → index.html
```

#### **Backend Layer**
```
backend/lambda-functions/
├── shared/utils.py     # Common utilities ← All Lambda functions depend on this
├── upload-file/        # File upload → S3 + DynamoDB + utils.py
├── download-file/      # File download → S3 + DynamoDB + utils.py
├── list-files/         # List files → DynamoDB + utils.py
├── delete-file/        # Delete files → S3 + DynamoDB + utils.py
├── share-file/         # Share files → DynamoDB + utils.py
├── get-shared-file/    # Access shared → S3 + DynamoDB + utils.py
└── deploy-functions.sh # Deployment → All Lambda functions
```

#### **Infrastructure Layer**
```
aws-infrastructure/
├── infrastructure/
│   ├── main.yaml              # Core AWS resources
│   ├── lambda-functions.yaml  # Lambda + API Gateway → main.yaml
│   └── deploy.sh             # Local deployment → main.yaml
└── scripts/
    └── deploy-complete-system.sh # Full deployment → All YAML files
```

### Dependency Chain
1. **Infrastructure** → Creates AWS resources (S3, DynamoDB, Cognito, IAM)
2. **Lambda Functions** → Deployed to infrastructure, uses shared utilities
3. **API Gateway** → Routes requests to Lambda functions
4. **Frontend** → Authenticates via Cognito, calls API Gateway

---

## ✨ Features

### 🔐 Authentication & Security
- **User Registration** - Create new accounts with email verification
- **User Login/Logout** - Secure authentication via AWS Cognito
- **Session Management** - Automatic token refresh and session handling
- **Role-based Access** - User-specific file access and permissions

### 📁 File Management
- **File Upload** - Drag & drop or click to upload files (any format)
- **File Download** - Secure download with presigned URLs
- **File Listing** - View all uploaded files with metadata
- **File Deletion** - Remove files from storage
- **File Metadata** - Track size, upload date, download count, tags

### 🔗 File Sharing
- **Generate Share Links** - Create secure, time-limited sharing URLs
- **Public Access** - Share files with non-registered users
- **Share Management** - Track and manage shared files
- **Expiration Control** - Automatic link expiration for security

### 📊 Dashboard & Analytics
- **File Statistics** - Total files, storage used, download counts
- **User Dashboard** - Personalized file management interface
- **Activity Tracking** - Monitor file access and sharing activity
- **Responsive Design** - Works on desktop, tablet, and mobile

### 🛡️ Enterprise Features
- **Encryption** - Files encrypted at rest (AES-256)
- **Versioning** - S3 versioning enabled for file history
- **CORS Support** - Cross-origin resource sharing configured
- **Scalability** - Serverless architecture scales automatically
- **Cost Optimization** - Pay-per-use pricing model

---

## 📋 Prerequisites

### Required Software
- **AWS CLI** (v2.0+) - `aws --version`
- **Python 3.9+** - `python3 --version`
- **Bash Shell** - For running deployment scripts
- **Web Browser** - Chrome, Firefox, Safari, or Edge

### AWS Requirements
- **AWS Account** with administrative access
- **AWS CLI configured** with credentials
- **Default region set** (recommended: us-east-1)

### Verify Prerequisites
```bash
# Check AWS CLI
aws --version
aws sts get-caller-identity

# Check Python
python3 --version

# Check region
aws configure get region
```

---

## 🚀 Deployment Guide

### Step 1: Clone/Download Project
```bash
# If you have the project, navigate to it
cd /path/to/cloud-file-storage-system
```

### Step 2: Deploy AWS Infrastructure
```bash
# Navigate to deployment scripts
cd aws-infrastructure/scripts

# Make script executable
chmod +x deploy-complete-system.sh

# Run complete deployment
./deploy-complete-system.sh
```

**Deployment Process:**
1. ✅ Validates AWS credentials and region
2. ✅ Creates S3 buckets (file storage + Lambda deployment)
3. ✅ Creates DynamoDB tables (metadata, permissions, shared files)
4. ✅ Sets up Cognito User Pool for authentication
5. ✅ Creates IAM roles and policies
6. ✅ Deploys Lambda functions
7. ✅ Configures API Gateway
8. ✅ Sets up CORS and security policies

**Expected Output:**
```
🚀 DEPLOYMENT COMPLETED SUCCESSFULLY!
================================
📍 Frontend URL: http://localhost:3000
🔗 API Endpoint: https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/prod
🔐 Cognito User Pool: us-east-1_xxxxxxxxx
📊 All services deployed and configured
```

### Step 3: Start Frontend Application
```bash
# Navigate to frontend
cd ../../frontend

# Start the application
./start.sh
```

### Step 4: Access Application
- Open browser to: `http://localhost:3000`
- Application will automatically connect to AWS backend

---

## 📖 Usage Guide

### First Time Setup

#### 1. Create Account
1. Open `http://localhost:3000`
2. Click **"Sign Up"**
3. Enter email and password
4. Check email for verification code
5. Enter verification code to activate account

#### 2. Login
1. Click **"Login"**
2. Enter email and password
3. You'll be redirected to the dashboard

### File Operations

#### Upload Files
1. **Drag & Drop**: Drag files onto the upload area
2. **Click Upload**: Click "Choose Files" button
3. **Add Metadata**: Optionally add description and tags
4. **Upload**: Click "Upload File" button

#### Download Files
1. Find file in the file list
2. Click **"Download"** button
3. File will download to your browser's download folder

#### Share Files
1. Find file in the file list
2. Click **"Share"** button
3. Copy the generated share link
4. Share link with others (works without login)

#### Delete Files
1. Find file in the file list
2. Click **"Delete"** button
3. Confirm deletion in the popup

### Dashboard Features

#### File Statistics
- **Total Files**: Number of files uploaded
- **Storage Used**: Total storage consumption
- **Downloads**: Total download count
- **Shares**: Number of shared files

#### File Management
- **Search**: Filter files by name
- **Sort**: Sort by date, size, or name
- **Bulk Operations**: Select multiple files for batch operations

---

## 📁 File Structure

### Production File Structure
```
cloud-file-storage-system/
├── frontend/                          # Web Interface
│   ├── index.html                    # Main application UI
│   ├── shared.html                   # Shared file viewer
│   └── start.sh                      # Frontend server startup
│
├── backend/lambda-functions/          # Serverless Backend
│   ├── shared/
│   │   └── utils.py                  # Common utilities for all functions
│   ├── upload-file/
│   │   └── index.py                  # File upload handler
│   ├── download-file/
│   │   └── index.py                  # File download handler
│   ├── list-files/
│   │   └── index.py                  # File listing handler
│   ├── delete-file/
│   │   └── index.py                  # File deletion handler
│   ├── share-file/
│   │   └── index.py                  # File sharing handler
│   ├── get-shared-file/
│   │   └── index.py                  # Shared file access handler
│   └── deploy-functions.sh           # Lambda deployment script
│
└── aws-infrastructure/                # Infrastructure as Code
    ├── infrastructure/
    │   ├── main.yaml                 # Core AWS resources (S3, DynamoDB, Cognito)
    │   ├── lambda-functions.yaml     # Lambda functions and API Gateway
    │   └── deploy.sh                 # Infrastructure deployment
    └── scripts/
        └── deploy-complete-system.sh # Complete system deployment
```

### File Purposes

#### Frontend Files
- **`index.html`**: Complete web application with authentication, file management, and sharing
- **`shared.html`**: Public interface for accessing shared files without login
- **`start.sh`**: Simple HTTP server to serve the frontend application

#### Lambda Functions
- **`upload-file`**: Handles file uploads to S3, stores metadata in DynamoDB
- **`download-file`**: Generates presigned URLs for secure file downloads
- **`list-files`**: Retrieves user's files from DynamoDB with pagination
- **`delete-file`**: Removes files from S3 and metadata from DynamoDB
- **`share-file`**: Creates shareable links with expiration times
- **`get-shared-file`**: Handles public access to shared files
- **`shared/utils.py`**: Common functions used by all Lambda functions

#### Infrastructure Files
- **`main.yaml`**: Creates S3 buckets, DynamoDB tables, Cognito User Pool, IAM roles
- **`lambda-functions.yaml`**: Defines Lambda functions, API Gateway, and routing
- **`deploy-complete-system.sh`**: Orchestrates complete deployment process

---

## 🔌 API Endpoints

### Authentication Endpoints
```
POST /auth/signup     # User registration
POST /auth/login      # User authentication
POST /auth/logout     # User logout
POST /auth/refresh    # Token refresh
```

### File Management Endpoints
```
GET    /files         # List user files
POST   /files         # Upload file
GET    /files/{id}    # Download file
DELETE /files/{id}    # Delete file
```

### File Sharing Endpoints
```
POST   /files/{id}/share    # Create share link
GET    /shared/{shareId}    # Access shared file
GET    /shared/{shareId}/info # Get shared file info
```

### API Response Format
```json
{
  "success": true,
  "data": {
    "files": [...],
    "message": "Operation completed"
  },
  "error": null
}
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Deployment Fails
**Problem**: CloudFormation stack creation fails
**Solution**:
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check region
aws configure get region

# Verify permissions
aws iam get-user
```

#### 2. Frontend Can't Connect to API
**Problem**: CORS or network errors
**Solution**:
1. Check API Gateway URL in browser console
2. Verify CORS configuration in AWS Console
3. Check browser network tab for failed requests

#### 3. Authentication Issues
**Problem**: Login fails or tokens expire
**Solution**:
1. Verify Cognito User Pool configuration
2. Check user verification status
3. Clear browser cache and cookies

#### 4. File Upload Fails
**Problem**: Files don't upload or upload errors
**Solution**:
1. Check file size limits (default: 10MB)
2. Verify S3 bucket permissions
3. Check Lambda function logs in CloudWatch

### Debugging Steps

#### 1. Check AWS Resources
```bash
# List CloudFormation stacks
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE

# Check S3 buckets
aws s3 ls

# Check DynamoDB tables
aws dynamodb list-tables
```

#### 2. View Lambda Logs
```bash
# List Lambda functions
aws lambda list-functions

# Get function logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/file-storage
```

#### 3. Test API Endpoints
```bash
# Test API Gateway
curl -X GET https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/health
```

### Performance Optimization

#### 1. Lambda Cold Starts
- Functions may take 1-2 seconds on first request
- Subsequent requests are faster (warm starts)

#### 2. File Size Limits
- Default Lambda payload limit: 6MB
- Large files use presigned URLs for direct S3 upload

#### 3. DynamoDB Performance
- Tables use on-demand billing for automatic scaling
- Global Secondary Indexes optimize query performance

---

## 📞 Support

### Getting Help
1. **Check Logs**: AWS CloudWatch logs for Lambda functions
2. **AWS Console**: Monitor resources in AWS Management Console
3. **Browser Console**: Check for JavaScript errors
4. **Network Tab**: Monitor API requests and responses

### Useful AWS CLI Commands
```bash
# Check stack status
aws cloudformation describe-stacks --stack-name file-storage-system-prod

# View Lambda function
aws lambda get-function --function-name file-storage-system-upload-file

# Check S3 bucket
aws s3 ls s3://file-storage-system-prod-123456789012

# View DynamoDB table
aws dynamodb describe-table --table-name file-storage-system-file-metadata
```

---

## 🎯 Next Steps

### Enhancements
1. **File Previews**: Add image/document preview capabilities
2. **Folder Organization**: Implement folder structure
3. **Advanced Sharing**: Add password protection and access controls
4. **Mobile App**: Create React Native or Flutter mobile application
5. **Admin Dashboard**: Add administrative interface for user management

### Scaling Considerations
1. **CDN**: Add CloudFront for global file distribution
2. **Multi-Region**: Deploy across multiple AWS regions
3. **Backup**: Implement cross-region S3 replication
4. **Monitoring**: Add comprehensive monitoring and alerting

---
