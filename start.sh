#!/bin/bash

echo "Starting Maya Koren Shechtman Website..."
echo "========================================"
echo ""
echo "Installing dependencies..."
npm install

echo ""
echo "Starting server..."
echo "Website will be available at: http://localhost:3000"
echo "Admin panel: http://localhost:3000/admin"
echo "Blog: http://localhost:3000/blog"
echo ""
echo "Admin credentials:"
echo "Username: admin"
echo "Password: admin"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

npm start
