#!/bin/bash

# codereview - Portable Automated Code Review Script
# Usage: codereview review.md <URL>
# Uses existing Claude Code configuration from ~/.claude.json

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    echo "Usage: $(basename $0) review.md <URL>"
    echo "Example: $(basename $0) review.md https://github.com/user/repo/pull/123"
    exit 1
fi

CONTEXT_FILE="$1"
URL="$2"

# Handle relative vs absolute paths for context file
if [[ "$CONTEXT_FILE" != /* ]]; then
    CONTEXT_FILE="$(pwd)/$CONTEXT_FILE"
fi

# Check if context file exists
if [ ! -f "$CONTEXT_FILE" ]; then
    print_status "error" "Context file '$CONTEXT_FILE' not found"
    exit 1
fi

# Check if Claude config exists
CLAUDE_CONFIG="$HOME/.claude.json"
if [ ! -f "$CLAUDE_CONFIG" ]; then
    print_status "error" "Claude config file '$CLAUDE_CONFIG' not found"
    print_status "info" "Please ensure you have Claude Code configured with MCP servers"
    exit 1
fi

# Check if GitHub MCP is configured
if ! grep -q '"github"' "$CLAUDE_CONFIG"; then
    print_status "warning" "GitHub MCP not found in Claude config"
    print_status "info" "Please configure GitHub MCP first with: claude mcp add github"
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
    exit 1
fi

print_status "success" "Prerequisites check passed"
print_status "info" "Using Claude config: $CLAUDE_CONFIG"

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

### GitHub Information
- **URL**: $URL
- **Owner**: $OWNER  
- **Repository**: $REPO
- **Pull Request**: #$PR_NUMBER

### Required Actions (Execute in sequence):

1. **Get PR Details**: Use GitHub MCP tool \`github:get_pull_request\` with owner: "$OWNER", repo: "$REPO", pull_number: $PR_NUMBER
2. **Get PR Files**: Use GitHub MCP tool \`github:get_pull_request_files\` with owner: "$OWNER", repo: "$REPO", pull_number: $PR_NUMBER  
3. **Analyze Key Files**: Use GitHub MCP tool \`github:get_file_contents\` for the most important changed files (max 3-5 files)
4. **Generate Review**: Create comprehensive code review following the specified format (DO NOT include any footer or signature such as "Generated with Claude Code")
5. **Post Review**: Use GitHub MCP tool \`github:create_pull_request_review\` with:
   - owner: "$OWNER"
   - repo: "$REPO" 
   - pull_number: $PR_NUMBER
   - body: [Complete review content]
   - event: "COMMENT" or "REQUEST_CHANGES" or "APPROVE" based on findings

### Output Format Required:
\`\`\`json
{
  "status": "success|error",
  "review_posted": true|false,
  "review_id": "review_id_if_successful",
  "event_type": "COMMENT|REQUEST_CHANGES|APPROVE",
  "files_analyzed": number,
  "issues_found": number,
  "summary": "Brief summary of what was done"
}
\`\`\`

**IMPORTANT**: Execute all steps automatically using ONLY GitHub MCP tools.
**CRITICAL**: Do NOT add any footer, signature, or attribution like "Generated with Claude Code" at the end of your review. The review should end with the Summary section only.

---

## 🚀 START AUTOMATED REVIEW NOW
EOF
}

# Generate prompt file in temp location
PROMPT_FILE="$(mktemp /tmp/codereview_prompt.XXXXXX.md)"
print_status "progress" "Generating automated review prompt..."
execute_automated_mcp_review > "$PROMPT_FILE"
print_status "success" "Automated prompt created: $PROMPT_FILE"

# Execute with claude-cli using home directory config
print_status "progress" "Executing claude-cli with existing MCP configuration..."

# Set environment to use home directory config
cd "$HOME"

if claude "$(cat "$PROMPT_FILE")"; then
    print_status "success" "Claude CLI executed successfully"
    print_status "info" "Check your GitHub PR for the posted review: $URL"
else
    print_status "error" "Claude CLI execution failed"
    rm -f "$PROMPT_FILE"
    exit 1
fi

# Cleanup
rm -f "$PROMPT_FILE"
print_status "success" "Review completed successfully"