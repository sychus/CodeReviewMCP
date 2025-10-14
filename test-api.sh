#!/bin/bash

echo "🧪 Testing CLI selection fix..."

# Wait a moment for server to start
sleep 3

echo "📡 Making curl request with prefer_cli='claude'..."

curl -X POST http://localhost:8787/review \
  -H "Content-Type: application/json" \
  -d '{
    "urls": ["https://github.com/blackthornio/events-webapp/pull/5668"],
    "prefer_cli": "claude",
    "debug": true
  }' \
  --connect-timeout 10 \
  --max-time 30 \
  | jq '.'

echo ""
echo "✅ Test completed. Check the output above for success/failure."
