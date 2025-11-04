#!/bin/bash
cd "$(dirname "$0")"
echo "🚀 Starting Cloud File Storage System Frontend..."
echo "📍 URL: http://localhost:3000"
echo "🔗 Backend: AWS Production"
echo "✅ All features available: SignUp, Login, Upload, Download, Share, Delete, List"
echo ""
python3 -m http.server 3000
