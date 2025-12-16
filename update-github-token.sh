#!/bin/bash

# update-github-token.sh
# Updates GitHub token in ~/.claude.json using GitHub CLI

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CLAUDE_CONFIG="$HOME/.claude.json"

echo -e "${BLUE}🔧 Updating GitHub token in Claude MCP${NC}"
echo ""

# Verify that gh is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo -e "${YELLOW}Install it with: brew install gh${NC}"
    exit 1
fi

echo -e "${GREEN}✅ GitHub CLI found${NC}"

# Verify authentication
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  You are not authenticated in GitHub CLI${NC}"
    echo -e "${BLUE}Starting authentication process...${NC}"
    echo ""
    gh auth login
else
    echo -e "${GREEN}✅ Already authenticated in GitHub CLI${NC}"
    echo ""
    gh auth status
fi

echo ""
echo -e "${BLUE}🔑 Obtaining token from GitHub CLI...${NC}"

# Get token from GitHub CLI
GH_TOKEN=$(gh auth token)

if [ -z "$GH_TOKEN" ]; then
    echo -e "${RED}❌ Could not obtain token from GitHub CLI${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Token obtained successfully${NC}"

# Verify that config file exists
if [ ! -f "$CLAUDE_CONFIG" ]; then
    echo -e "${RED}❌ Could not find $CLAUDE_CONFIG${NC}"
    exit 1
fi

echo -e "${BLUE}📝 Updating $CLAUDE_CONFIG...${NC}"

# Create backup
cp "$CLAUDE_CONFIG" "$CLAUDE_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}✅ Backup created${NC}"

# Update token using jq (if available) or sed
if command -v jq &> /dev/null; then
    # Use jq to update JSON safely
    jq --arg token "$GH_TOKEN" \
       '.mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN = $token' \
       "$CLAUDE_CONFIG" > "$CLAUDE_CONFIG.tmp" && \
       mv "$CLAUDE_CONFIG.tmp" "$CLAUDE_CONFIG"
    echo -e "${GREEN}✅ Token updated with jq${NC}"
else
    # Fallback: use sed (less safe but functional)
    echo -e "${YELLOW}⚠️  jq is not installed, using sed (install jq with: brew install jq)${NC}"
    
    # Find and replace old token
    sed -i.tmp "s|\"GITHUB_PERSONAL_ACCESS_TOKEN\": \"github_pat_[^\"]*\"|\"GITHUB_PERSONAL_ACCESS_TOKEN\": \"$GH_TOKEN\"|g" "$CLAUDE_CONFIG"
    rm -f "$CLAUDE_CONFIG.tmp"
    echo -e "${GREEN}✅ Token updated with sed${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Token updated successfully!${NC}"
echo ""
echo -e "${BLUE}📝 Information:${NC}"
echo -e "  • Token obtained from: ${YELLOW}gh auth token${NC}"
echo -e "  • GitHub user: ${YELLOW}$(gh api user -q .login)${NC}"
echo -e "  • Configuration: ${YELLOW}$CLAUDE_CONFIG${NC}"
echo -e "  • Backup saved at: ${YELLOW}$CLAUDE_CONFIG.backup.*${NC}"
echo ""
echo -e "${BLUE}🔄 To renew the token in the future:${NC}"
echo -e "  1. Run: ${YELLOW}gh auth refresh${NC}"
echo -e "  2. Run: ${YELLOW}./update-github-token.sh${NC}"
echo ""
echo -e "${BLUE}🧪 Test your configuration with:${NC}"
echo -e "  ${YELLOW}./codereview.sh review.md https://github.com/owner/repo/pull/123${NC}"
