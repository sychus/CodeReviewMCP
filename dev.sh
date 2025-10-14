#!/bin/bash

# Quick development script for CodeReview API

set -e

echo "🚀 Starting CodeReview API Development Server..."

# Check if Deno is installed
if ! command -v deno &> /dev/null; then
    echo "❌ Deno is not installed. Please install Deno first:"
    echo "   curl -fsSL https://deno.land/install.sh | sh"
    exit 1
fi

# Check if codereview.sh exists
if [ ! -f "./codereview.sh" ]; then
    echo "❌ codereview.sh not found in current directory"
    exit 1
fi

# Make sure codereview.sh is executable
chmod +x ./codereview.sh

# Load environment variables if .env exists
if [ -f ".env" ]; then
    echo "📄 Loading environment variables from .env"
    export $(cat .env | grep -v '^#' | xargs)
fi

# Start the development server
echo "🌟 Server will be available at http://localhost:${PORT:-8787}"
echo "📚 API documentation at http://localhost:${PORT:-8787}/"
echo "🔍 Health check at http://localhost:${PORT:-8787}/health"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

deno task dev
