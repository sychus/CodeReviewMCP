#!/bin/bash

# codereview - Automated Code Review Script with GitHub MCP via claude-cli
# Author: sychus (https://github.com/sychus)
# Repository: https://github.com/sychus/codereview-mcp-claude-code
# Usage: codereview review.md <URL>
# Example: codereview review.md https://github.com/user/repo/pull/123

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Status printer
print_status() {
    local status="$1"
    local message="$2"
    case $status in
        "info") echo -e "${CYAN}ℹ${NC}  $message" ;;
        "success") echo -e "${GREEN}✅${NC} $message" ;;
        "warning") echo -e "${YELLOW}⚠️${NC}  $message" ;;
        "error") echo -e "${RED}❌${NC} $message" ;;
        "progress") echo -e "${BLUE}🔄${NC} $message" ;;
    esac
}

# Argument check
if [ "$#" -ne 2 ]; then
    echo "Usage: codereview review.md <URL>"
    exit 1
fi

CONTEXT_FILE="$1"
URL="$2"

# File exists?
if [ ! -f "$CONTEXT_FILE" ]; then
    print_status "error" "Context file '$CONTEXT_FILE' not found"
    exit 1
fi

# Extract repo info
print_status "info" "Analyzing URL: $URL"
if [[ $URL =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    PR_NUMBER="${BASH_REMATCH[3]}"
    print_status "success" "Detected Pull Request: $OWNER/$REPO PR #$PR_NUMBER"
else
    print_status "error" "Invalid GitHub PR URL format"
    exit 1
fi

# Check tools
if ! command -v claude &>/dev/null; then
    print_status "error" "Claude CLI is required but not found"
    print_status "info" "Install with: npm install -g claude-cli"
    exit 1
fi

print_status "success" "Prerequisites check passed (Claude CLI ready)"

# Function: generate automated MCP prompt
execute_automated_mcp_review() {
    local context_content
    context_content=$(cat "$CONTEXT_FILE" | sed "s|{URL_PARAMETER}|$URL|g")
    
    cat << EOF
## 🚨 CRITICAL TOOL RESTRICTIONS
**MANDATORY**: You MUST ONLY use GitHub MCP server tools. DO NOT use any bash commands, CLI tools, or external commands.

**FORBIDDEN COMMANDS**: 
- gh (GitHub CLI)
- curl 
- git commands
- bash commands for GitHub operations

**REQUIRED**: Use ONLY these GitHub MCP tools:
- github:get_pull_request
- github:get_pull_request_files  
- github:get_file_contents
- github:create_pull_request_review

---

$context_content

## 🤖 AUTOMATED EXECUTION MODE

You are executing in automated mode. Follow these steps EXACTLY using ONLY GitHub MCP tools:

### GitHub Information
- **URL**: $URL
- **Owner**: $OWNER  
- **Repository**: $REPO
- **Pull Request**: #$PR_NUMBER

### Required Actions (Execute in sequence):

1. **Get PR Details**: Use GitHub MCP tool \`github:get_pull_request\` with owner: "$OWNER", repo: "$REPO", pull_number: $PR_NUMBER
2. **Get PR Files**: Use GitHub MCP tool \`github:get_pull_request_files\` with owner: "$OWNER", repo: "$REPO", pull_number: $PR_NUMBER  
3. **Analyze Key Files**: Use GitHub MCP tool \`github:get_file_contents\` for the most important changed files (max 3-5 files)
4. **Generate Review**: Create comprehensive code review following the specified format
5. **Post Review**: Use GitHub MCP tool \`github:create_pull_request_review\` with:
   - owner: "$OWNER"
   - repo: "$REPO" 
   - pull_number: $PR_NUMBER
   - body: [Complete review content]
   - event: "COMMENT" or "REQUEST_CHANGES" or "APPROVE" based on findings

### EXAMPLE MCP TOOL USAGE:
\`\`\`
Step 1: github:get_pull_request
{
  "owner": "$OWNER",
  "repo": "$REPO", 
  "pull_number": $PR_NUMBER
}

Step 2: github:get_pull_request_files  
{
  "owner": "$OWNER",
  "repo": "$REPO",
  "pull_number": $PR_NUMBER
}
\`\`\`

### Output Format Required:
At the end, provide a JSON summary like this:
\`\`\`json
{
  "status": "success|error",
  "review_posted": true|false,
  "review_id": "review_id_if_successful",
  "review_url": "github_url_if_successful", 
  "event_type": "COMMENT|REQUEST_CHANGES|APPROVE",
  "files_analyzed": number,
  "issues_found": number,
  "summary": "Brief summary of what was done"
}
\`\`\`

**IMPORTANT**: Execute all steps automatically using ONLY GitHub MCP tools. Do not ask for permission, just execute.

---

## 🚀 START AUTOMATED REVIEW NOW USING GITHUB MCP
EOF
}

# Generate prompt file
PROMPT_FILE=".codereview_prompt.md"
print_status "progress" "Generating automated review prompt..."
execute_automated_mcp_review > "$PROMPT_FILE"
print_status "success" "Automated prompt created: $PROMPT_FILE"
print_status "info" "Target: $OWNER/$REPO PR #$PR_NUMBER"

# Execute with claude-cli
print_status "progress" "Executing claude-cli with MCP GitHub..."
# Detect config dir: use $CLAUDE_CONFIG_DIR if set, else use script dir
if [ -n "$CLAUDE_CONFIG_DIR" ]; then
    CONFIG_DIR="$CLAUDE_CONFIG_DIR"
else
    CONFIG_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Export config dir for Claude CLI if supported
export CLAUDE_CONFIG_DIR="$CONFIG_DIR"

if CLAUDE_CONFIG_DIR="$CONFIG_DIR" claude "$(cat "$PROMPT_FILE")"; then
    print_status "success" "Claude CLI executed successfully"
    print_status "info" "Check your GitHub PR for the posted review"
else
    print_status "error" "Claude CLI execution failed"
    exit 1
fi