#!/bin/bash

# Test script to verify PREFERRED_CLI environment variable is working

echo "Testing PREFERRED_CLI environment variable..."

# Test 1: Direct environment variable test
echo "Test 1: Setting PREFERRED_CLI=claude"
PREFERRED_CLI=claude ./codereview.sh --debug review.md https://github.com/blackthornio/events-webapp/pull/5668

echo ""
echo "If the test above shows 'Using preferred CLI: claude', then the fix is working!"
