# ☁️ Cloud File Storage System

A production-ready, serverless file storage application built on AWS with secure authentication, file sharing, and management capabilities.

## 🚀 Features

- **🔐 Secure Authentication** - AWS Cognito user management
- **📁 File Management** - Upload, download, delete files
- **🔗 File Sharing** - Generate secure sharing links
- **📊 Dashboard** - File statistics and management
- **🛡️ Enterprise Security** - Encryption, CORS, role-based access
- **⚡ Serverless Architecture** - Auto-scaling, cost-effective

## 🏗️ Architecture

```
Frontend (HTML/JS) → API Gateway → Lambda Functions → S3 + DynamoDB
                  ↘ Cognito (Auth)
```

## 📋 Prerequisites

- AWS CLI configured
- Python 3.9+
- Bash shell
- Web browser

## 🚀 Quick Start

### 1. Deploy Infrastructure
```bash
cd aws-infrastructure/scripts
./deploy-complete-system.sh
```

### 2. Start Application
```bash
cd frontend
./start.sh
```

### 3. Access Application
Open `http://localhost:3000` in your browser

## 📁 Project Structure

```
cloud-file-storage-system/
├── frontend/                    # Web interface
│   ├── index.html              # Main application
│   ├── shared.html             # Shared file viewer
│   └── start.sh               # Server startup
├── backend/lambda-functions/    # Serverless backend
│   ├── upload-file/           # File upload handler
│   ├── download-file/         # File download handler
│   ├── list-files/           # File listing handler
│   ├── delete-file/          # File deletion handler
│   ├── share-file/           # File sharing handler
│   ├── get-shared-file/      # Shared file access
│   └── shared/utils.py       # Common utilities
└── aws-infrastructure/         # Infrastructure as Code
    ├── infrastructure/        # CloudFormation templates
    └── scripts/              # Deployment scripts
```

## 🔌 API Endpoints

- `GET /files` - List user files
- `POST /files` - Upload file
- `GET /files/{id}` - Download file
- `DELETE /files/{id}` - Delete file
- `POST /files/{id}/share` - Create share link
- `GET /shared/{shareId}` - Access shared file

## 🛠️ Technology Stack

- **Frontend**: HTML5, CSS3, JavaScript
- **Backend**: AWS Lambda (Python 3.9)
- **Database**: Amazon DynamoDB
- **Storage**: Amazon S3
- **Authentication**: Amazon Cognito
- **API**: Amazon API Gateway
- **Infrastructure**: AWS CloudFormation

## 📖 Documentation

See [COMPLETE_DOCUMENTATION.md](./COMPLETE_DOCUMENTATION.md) for detailed setup, usage, and troubleshooting guide.

## 🔧 Troubleshooting

### Common Issues
1. **Deployment fails** - Check AWS credentials and permissions
2. **CORS errors** - Verify API Gateway CORS configuration
3. **Authentication issues** - Check Cognito User Pool settings

### Debug Commands
```bash
# Check AWS resources
aws cloudformation list-stacks
aws s3 ls
aws dynamodb list-tables

# View Lambda logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/file-storage
```

## 📞 Support

For issues and questions:
1. Check AWS CloudWatch logs
2. Verify AWS resource status in console
3. Review browser console for frontend errors

## 🎯 Future Enhancements

- [ ] File previews and thumbnails
- [ ] Folder organization
- [ ] Advanced sharing controls
- [ ] Mobile application
- [ ] Admin dashboard

---

**🎉 Built with AWS serverless technologies for scalability and reliability.**
