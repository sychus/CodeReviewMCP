#!/bin/bash

# codereview.sh - Unified Automated Code Review Script (Claude, Gemini & Codex)
# Usage: codereview.sh review.md <URL>

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
        "info") echo -e "${CYAN}\u2139${NC}  $message" ;;
        "success") echo -e "${GREEN}\u2705${NC} $message" ;;
        "warning") echo -e "${YELLOW}\u26a0\ufe0f${NC}  $message" ;;
        "error") echo -e "${RED}\u274c${NC} $message" ;;
        "progress") echo -e "${BLUE}\ud83d\udd04${NC} $message" ;;
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

# Tool detection
HAS_CLAUDE=false
HAS_GEMINI=false
HAS_CODEX=false
if command -v claude &>/dev/null; then
    HAS_CLAUDE=true
fi
if command -v gemini &>/dev/null; then
    HAS_GEMINI=true
fi
if command -v codex &>/dev/null; then
    HAS_CODEX=true
fi

if ! $HAS_CLAUDE && ! $HAS_GEMINI && ! $HAS_CODEX; then
    print_status "error" "No supported CLI found (Claude, Gemini, or Codex). Please install at least one."
    exit 1
fi

# Select tool if multiple are present
AVAILABLE_TOOLS=()
if $HAS_CLAUDE; then
    AVAILABLE_TOOLS+=("claude")
fi
if $HAS_GEMINI; then
    AVAILABLE_TOOLS+=("gemini")
fi
if $HAS_CODEX; then
    AVAILABLE_TOOLS+=("codex")
fi

if [ ${#AVAILABLE_TOOLS[@]} -gt 1 ]; then
    print_status "info" "Multiple CLIs detected: ${AVAILABLE_TOOLS[*]}"
    echo "Select which CLI to use for the review:"
    select TOOL in "${AVAILABLE_TOOLS[@]}"; do
        case $TOOL in
            claude|gemini|codex) SELECTED_TOOL="$TOOL"; break ;;
            *) echo "Invalid option. Please select a valid number." ;;
        esac
    done
else
    SELECTED_TOOL="${AVAILABLE_TOOLS[0]}"
    print_status "info" "Using $SELECTED_TOOL CLI."
fi

# Config and prompt logic
if [ "$SELECTED_TOOL" = "claude" ]; then
    CLAUDE_CONFIG="$HOME/.claude.json"
    if [ ! -f "$CLAUDE_CONFIG" ]; then
        print_status "error" "Claude config file '$CLAUDE_CONFIG' not found"
        print_status "info" "Please ensure you have Claude Code configured with MCP servers"
        exit 1
    fi
    if ! grep -q '"github"' "$CLAUDE_CONFIG"; then
        print_status "warning" "GitHub MCP not found in Claude config"
        print_status "info" "Please configure GitHub MCP first with: claude mcp add github"
    fi
elif [ "$SELECTED_TOOL" = "gemini" ]; then
    GEMINI_CONFIG="$HOME/.gemini/settings.json"
    if [ ! -f "$GEMINI_CONFIG" ]; then
        print_status "error" "Gemini config file '$GEMINI_CONFIG' not found"
        print_status "info" "Please ensure you have Gemini configured with MCP servers"
        exit 1
    fi
    if ! grep -q '"github"' "$GEMINI_CONFIG"; then
        print_status "warning" "GitHub MCP not found in Gemini config"
        print_status "info" "Please configure GitHub MCP first in .gemini/settings.json"
    fi
elif [ "$SELECTED_TOOL" = "codex" ]; then
    # Codex config verification
    CODEX_CONFIG="$HOME/.codex/config.toml"
    if [ ! -f "$CODEX_CONFIG" ]; then
        print_status "error" "Codex config file '$CODEX_CONFIG' not found"
        print_status "info" "Please ensure you have Codex configured with MCP servers"
        print_status "info" "Create config with: mkdir -p ~/.codex && codex init"
        exit 1
    fi
    # Check if GitHub MCP is configured in TOML format
    if ! grep -q -i "github" "$CODEX_CONFIG"; then
        print_status "warning" "GitHub MCP not found in Codex config"
        print_status "info" "Please configure GitHub MCP in your ~/.codex/config.toml file"
        print_status "info" "Add MCP server configuration for GitHub in your TOML config"
    fi
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

print_status "success" "Prerequisites check passed"

# Prompt generation functions
execute_automated_claude_review() {
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

1. **Get PR Details**: Use GitHub MCP tool `github:get_pull_request` with owner: "$OWNER", repo: "$REPO", pull_number: $PR_NUMBER
2. **Get PR Files**: Use GitHub MCP tool `github:get_pull_request_files` with owner: "$OWNER", repo: "$REPO", pull_number: $PR_NUMBER  
3. **Analyze Key Files**: Use GitHub MCP tool `github:get_file_contents` for the most important changed files (max 3-5 files)
4. **Generate Review**: Create comprehensive code review following the specified format (DO NOT include any footer or signature such as "Generated with Claude Code")
5. **Post Review**: Use GitHub MCP tool `github:create_pull_request_review` with:
   - owner: "$OWNER"
   - repo: "$REPO" 
   - pull_number: $PR_NUMBER
   - body: [Complete review content]
   - event: "COMMENT" or "REQUEST_CHANGES" or "APPROVE" based on findings

### Output Format Required:
```json
{
  "status": "success|error",
  "review_posted": true|false,
  "review_id": "review_id_if_successful",
  "event_type": "COMMENT|REQUEST_CHANGES|APPROVE",
  "files_analyzed": number,
  "issues_found": number,
  "summary": "Brief summary of what was done"
}
```

**IMPORTANT**: Execute all steps automatically using ONLY GitHub MCP tools.
**CRITICAL**: Do NOT add any footer, signature, or attribution like "Generated with Claude Code" at the end of your review. The review should end with the Summary section only.

---

## 🚀 START AUTOMATED REVIEW NOW
EOF
}

execute_automated_gemini_review() {
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
- github:get_pull_request OR mcp_github_get_pull_request
- github:get_pull_request_files OR mcp_github_get_pull_request_files  
- github:get_file_contents OR mcp_github_get_file_contents
- github:create_pull_request_review OR mcp_github_create_pull_request_review

---

$context_content

## 🤖 AUTOMATED EXECUTION MODE

### GitHub Information
- **URL**: $URL
- **Owner**: $OWNER  
- **Repository**: $REPO
- **Pull Request**: #$PR_NUMBER

### Required Actions (Execute in sequence):

1. **Get PR Details**: Use available GitHub MCP tool (try `github:get_pull_request` first, if not available use `mcp_github_get_pull_request`) with owner: "$OWNER", repo: "$REPO", pull_number: $PR_NUMBER
2. **Get PR Files**: Use available GitHub MCP tool (try `github:get_pull_request_files` first, if not available use `mcp_github_get_pull_request_files`) with owner: "$OWNER", repo: "$REPO", pull_number: $PR_NUMBER  
3. **Analyze Key Files**: Use available GitHub MCP tool (try `github:get_file_contents` first, if not available use `mcp_github_get_file_contents`) for the most important changed files (max 3-5 files)
4. **Generate Review**: Create comprehensive code review following the specified format (DO NOT include any footer or signature such as "Generated with Gemini")
5. **Post Review**: Use available GitHub MCP tool (try `github:create_pull_request_review` first, if not available use `mcp_github_create_pull_request_review`) with:
   - owner: "$OWNER"
   - repo: "$REPO" 
   - pull_number: $PR_NUMBER
   - body: [Complete review content]
   - event: "COMMENT" or "REQUEST_CHANGES" or "APPROVE" based on findings

### Output Format Required:
```json
{
  "status": "success|error",
  "review_posted": true|false,
  "review_id": "review_id_if_successful",
  "event_type": "COMMENT|REQUEST_CHANGES|APPROVE",
  "files_analyzed": number,
  "issues_found": number,
  "summary": "Brief summary of what was done"
}
```

**IMPORTANT**: Execute all steps automatically using ONLY GitHub MCP tools.
**CRITICAL**: Do NOT add any footer, signature, or attribution like "Generated with Gemini" at the end of your review. The review should end with the Summary section only.

---

## 🚀 START AUTOMATED REVIEW NOW
EOF
}

execute_automated_codex_review() {
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
- github:get_pull_request OR mcp_github_get_pull_request
- github:get_pull_request_files OR mcp_github_get_pull_request_files  
- github:get_file_contents OR mcp_github_get_file_contents
- github:create_pull_request_review OR mcp_github_create_pull_request_review

---

$context_content

## 🤖 AUTOMATED EXECUTION MODE

### GitHub Information
- **URL**: $URL
- **Owner**: $OWNER  
- **Repository**: $REPO
- **Pull Request**: #$PR_NUMBER

### Required Actions (Execute in sequence):

1. **Get PR Details**: Use available GitHub MCP tool (try `github:get_pull_request` first, if not available use `mcp_github_get_pull_request`) with owner: "$OWNER", repo: "$REPO", pull_number: $PR_NUMBER
2. **Get PR Files**: Use available GitHub MCP tool (try `github:get_pull_request_files` first, if not available use `mcp_github_get_pull_request_files`) with owner: "$OWNER", repo: "$REPO", pull_number: $PR_NUMBER  
3. **Analyze Key Files**: Use available GitHub MCP tool (try `github:get_file_contents` first, if not available use `mcp_github_get_file_contents`) for the most important changed files (max 3-5 files)
4. **Generate Review**: Create comprehensive code review following the specified format (DO NOT include any footer or signature such as "Generated with Codex")
5. **Post Review**: Use available GitHub MCP tool (try `github:create_pull_request_review` first, if not available use `mcp_github_create_pull_request_review`) with:
   - owner: "$OWNER"
   - repo: "$REPO" 
   - pull_number: $PR_NUMBER
   - body: [Complete review content]
   - event: "COMMENT" or "REQUEST_CHANGES" or "APPROVE" based on findings

### Output Format Required:
```json
{
  "status": "success|error",
  "review_posted": true|false,
  "review_id": "review_id_if_successful",
  "event_type": "COMMENT|REQUEST_CHANGES|APPROVE",
  "files_analyzed": number,
  "issues_found": number,
  "summary": "Brief summary of what was done"
}
```

**IMPORTANT**: Execute all steps automatically using ONLY GitHub MCP tools.
**CRITICAL**: Do NOT add any footer, signature, or attribution like "Generated with Codex" at the end of your review. The review should end with the Summary section only.

---

## 🚀 START AUTOMATED REVIEW NOW
EOF
}

# Generate prompt file in temp location
PROMPT_FILE="$(mktemp /tmp/codereview_prompt.XXXXXX.md)"
print_status "progress" "Generating automated review prompt..."
if [ "$SELECTED_TOOL" = "claude" ]; then
    execute_automated_claude_review > "$PROMPT_FILE"
elif [ "$SELECTED_TOOL" = "gemini" ]; then
    execute_automated_gemini_review > "$PROMPT_FILE"
elif [ "$SELECTED_TOOL" = "codex" ]; then
    execute_automated_codex_review > "$PROMPT_FILE"
fi
print_status "success" "Automated prompt created: $PROMPT_FILE"

# Execute with selected CLI
print_status "progress" "Executing $SELECTED_TOOL with MCP configuration..."
if [ "$SELECTED_TOOL" = "claude" ]; then
    cd "$HOME"
    if claude "$(cat "$PROMPT_FILE")"; then
        print_status "success" "Claude CLI executed successfully"
        print_status "info" "Check your GitHub PR for the posted review: $URL"
    else
        print_status "error" "Claude CLI execution failed"
        rm -f "$PROMPT_FILE"
        exit 1
    fi
elif [ "$SELECTED_TOOL" = "gemini" ]; then
    if gemini -p "$(cat "$PROMPT_FILE")"; then
        print_status "success" "Gemini executed successfully"
        print_status "info" "Check your GitHub PR for the posted review: $URL"
    else
        print_status "error" "Gemini execution failed"
        rm -f "$PROMPT_FILE"
        exit 1
    fi
elif [ "$SELECTED_TOOL" = "codex" ]; then
    if codex "$(cat "$PROMPT_FILE")"; then
        print_status "success" "Codex executed successfully"
        print_status "info" "Check your GitHub PR for the posted review: $URL"
    else
        print_status "error" "Codex execution failed"
        rm -f "$PROMPT_FILE"
        exit 1
    fi
fi

# Cleanup
rm -f "$PROMPT_FILE"
print_status "success" "Review completed successfully"