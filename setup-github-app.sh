#!/bin/bash

# setup-github-app.sh
# Helper script to configure GitHub App authentication for CodeReview MCP

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🚀 GitHub App Setup Helper for CodeReview MCP${NC}"
echo ""

# Function to validate required inputs
validate_input() {
    local input="$1"
    local name="$2"
    if [ -z "$input" ]; then
        echo -e "${RED}❌ $name cannot be empty${NC}"
        exit 1
    fi
}

# Collect GitHub App information
echo -e "${CYAN}📋 Please provide your GitHub App information:${NC}"
echo ""

read -p "GitHub App ID: " APP_ID
validate_input "$APP_ID" "GitHub App ID"

read -p "GitHub Installation ID: " INSTALLATION_ID
validate_input "$INSTALLATION_ID" "GitHub Installation ID"

read -p "Path to private key file (.pem): " PRIVATE_KEY_PATH
validate_input "$PRIVATE_KEY_PATH" "Private key path"

# Validate private key file exists
if [ ! -f "$PRIVATE_KEY_PATH" ]; then
    echo -e "${RED}❌ Private key file not found: $PRIVATE_KEY_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All inputs validated${NC}"
echo ""

# Choose CLI to configure
echo -e "${CYAN}🔧 Which CLI would you like to configure?${NC}"
select CLI in "Claude" "Gemini" "Codex" "All"; do
    case $CLI in
        Claude|Gemini|Codex|All)
            echo -e "${GREEN}✅ Selected: $CLI${NC}"
            break
            ;;
        *)
            echo -e "${YELLOW}Please select a valid option${NC}"
            ;;
    esac
done

echo ""

# Configure Claude
configure_claude() {
    echo -e "${BLUE}🔧 Configuring Claude MCP with GitHub App...${NC}"
    
    claude mcp add github -s user \
        -e GITHUB_APP_ID="$APP_ID" \
        -e GITHUB_PRIVATE_KEY="$(cat "$PRIVATE_KEY_PATH")" \
        -e GITHUB_INSTALLATION_ID="$INSTALLATION_ID" \
        -- docker run -i --rm \
        -e GITHUB_APP_ID \
        -e GITHUB_PRIVATE_KEY \
        -e GITHUB_INSTALLATION_ID \
        ghcr.io/github/github-mcp-server
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Claude MCP configured successfully${NC}"
    else
        echo -e "${RED}❌ Failed to configure Claude MCP${NC}"
        return 1
    fi
}

# Configure Gemini (placeholder - adjust based on actual Gemini CLI)
configure_gemini() {
    echo -e "${BLUE}🔧 Configuring Gemini MCP with GitHub App...${NC}"
    echo -e "${YELLOW}⚠️  Please configure Gemini MCP manually with these environment variables:${NC}"
    echo "GITHUB_APP_ID=$APP_ID"
    echo "GITHUB_INSTALLATION_ID=$INSTALLATION_ID"
    echo "GITHUB_PRIVATE_KEY=<contents of $PRIVATE_KEY_PATH>"
}

# Configure Codex (placeholder - adjust based on actual Codex CLI)
configure_codex() {
    echo -e "${BLUE}🔧 Configuring Codex MCP with GitHub App...${NC}"
    echo -e "${YELLOW}⚠️  Please add these settings to your ~/.codex/config.toml:${NC}"
    echo ""
    echo "[github]"
    echo "app_id = \"$APP_ID\""
    echo "installation_id = \"$INSTALLATION_ID\""
    echo "private_key_path = \"$PRIVATE_KEY_PATH\""
}

# Execute configuration based on selection
case $CLI in
    "Claude")
        configure_claude
        ;;
    "Gemini")
        configure_gemini
        ;;
    "Codex")
        configure_codex
        ;;
    "All")
        configure_claude
        echo ""
        configure_gemini
        echo ""
        configure_codex
        ;;
esac

echo ""
echo -e "${CYAN}🧪 Testing configuration...${NC}"

# Test configuration
if [ "$CLI" = "Claude" ] || [ "$CLI" = "All" ]; then
    echo -e "${BLUE}Testing Claude MCP...${NC}"
    if claude mcp list | grep -q "github"; then
        echo -e "${GREEN}✅ Claude GitHub MCP is configured${NC}"
    else
        echo -e "${RED}❌ Claude GitHub MCP not found${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 Setup complete!${NC}"
echo ""
echo -e "${CYAN}📚 Next steps:${NC}"
echo "1. Test your configuration with: ./codereview.sh review.md <GitHub-PR-URL>"
echo "2. If you encounter issues, check the troubleshooting section in README.md"
echo "3. For security, consider rotating your private key regularly"
echo ""
echo -e "${YELLOW}💡 Pro tip: Set PREFERRED_CLI environment variable to skip CLI selection:${NC}"
echo "   export PREFERRED_CLI=claude"
echo "   ./codereview.sh review.md <GitHub-PR-URL>"
