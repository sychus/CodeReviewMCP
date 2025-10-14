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

# Parse arguments including debug flag
DEBUG_MODE=false
CONTEXT_FILE=""
URLS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        -*)
            print_status "error" "Unknown option: $1"
            exit 1
            ;;
        *)
            if [ -z "$CONTEXT_FILE" ]; then
                CONTEXT_FILE="$1"
            else
                URLS+=("$1")
            fi
            shift
            ;;
    esac
done

# Argument check
if [ -z "$CONTEXT_FILE" ] || [ ${#URLS[@]} -eq 0 ]; then
    echo "Usage: $(basename $0) [--debug] review.md <URL1> [URL2] [URL3] ..."
    echo "Examples:"
    echo "  Single PR: $(basename $0) review.md https://github.com/user/repo/pull/123"
    echo "  Multiple PRs: $(basename $0) review.md https://github.com/user/repo1/pull/123 https://github.com/user/repo2/pull/456"
    echo "  Debug mode: $(basename $0) --debug review.md https://github.com/user/repo/pull/123"
    exit 1
fi

if [ "$DEBUG_MODE" = true ]; then
    print_status "info" "🐛 Debug mode enabled"
fi

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

# Helper function to select CLI tool interactively or by default
select_cli_tool() {
    local tools=("${AVAILABLE_TOOLS[@]}")
    if [ ${#tools[@]} -gt 1 ]; then
        print_status "info" "Multiple CLIs detected: ${tools[*]}"
        echo "Select which CLI to use for the review:"
        select TOOL in "${tools[@]}"; do
            case $TOOL in
                claude|gemini|codex) SELECTED_TOOL="$TOOL"; break ;;
                *) echo "Invalid option. Please select a valid number." ;;
            esac
        done
    else
        SELECTED_TOOL="${tools[0]}"
        print_status "info" "Using $SELECTED_TOOL CLI."
    fi
}

# Check if a preferred CLI is specified via environment variable
if [ -n "$PREFERRED_CLI" ]; then
    # Validate that the preferred CLI is available
    if [[ " ${AVAILABLE_TOOLS[*]} " =~ " $PREFERRED_CLI " ]]; then
        SELECTED_TOOL="$PREFERRED_CLI"
        print_status "info" "Using preferred CLI: $SELECTED_TOOL"
    else
        print_status "warning" "Preferred CLI '$PREFERRED_CLI' not available. Available CLIs: ${AVAILABLE_TOOLS[*]}"
        select_cli_tool
    fi
elif [ ${#AVAILABLE_TOOLS[@]} -gt 1 ]; then
    select_cli_tool
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

# Validate URLs format before processing
print_status "info" "Validating ${#URLS[@]} URL(s)..."
for url in "${URLS[@]}"; do
    if [[ ! $url =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
        print_status "error" "Invalid GitHub PR URL format: $url"
        exit 1
    fi
done

print_status "success" "All URLs validated successfully"
print_status "success" "Prerequisites check passed"

# Prompt generation functions
execute_automated_claude_review() {
    local context_content
    context_content=$(cat "$CONTEXT_FILE" | sed "s|{URL_PARAMETER}|{URL_PARAMETER}|g")
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

### Required Actions (Execute in sequence):

1. **Parse URL**: Extract owner, repo, and pull request number from the provided GitHub PR URL
2. **Get PR Details**: Use GitHub MCP tool \`github:get_pull_request\` with the extracted owner, repo, and pull_number
3. **Get PR Files**: Use GitHub MCP tool \`github:get_pull_request_files\` with the extracted owner, repo, and pull_number  
4. **Analyze Key Files**: Use GitHub MCP tool \`github:get_file_contents\` for the most important changed files (max 3-5 files)
5. **Generate Review**: Create comprehensive code review following the specified format (DO NOT include any footer or signature such as "Generated with Claude Code")
6. **Post Review**: Use GitHub MCP tool \`github:create_pull_request_review\` with the extracted owner, repo, and pull_number
   - body: [Complete review content]
   - event: "COMMENT" or "REQUEST_CHANGES" or "APPROVE" based on findings

### Output Format Required:
\`\`\`json
{
  \"status\": \"success|error\",
  \"review_posted\": true|false,
  \"review_id\": \"review_id_if_successful\",
  \"event_type\": \"COMMENT|REQUEST_CHANGES|APPROVE\",
  \"files_analyzed\": number,
  \"issues_found\": number,
  \"summary\": \"Brief summary of what was done\"
}
\`\`\`

**IMPORTANT**: Execute all steps automatically using ONLY GitHub MCP tools.
**CRITICAL**: Do NOT add any footer, signature, or attribution like "Generated with Claude Code" at the end of your review. The review should end with the Summary section only.

---

## 🚀 START AUTOMATED REVIEW NOW
EOF
}

execute_automated_gemini_review() {
    local context_content
    context_content=$(cat "$CONTEXT_FILE" | sed "s|{URL_PARAMETER}|{URL_PARAMETER}|g")
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

### Required Actions (Execute in sequence):

1. **Parse URL**: Extract owner, repo, and pull request number from the provided GitHub PR URL
2. **Get PR Details**: Use available GitHub MCP tool (try \`github:get_pull_request\` first, if not available use \`mcp_github_get_pull_request\`) with the extracted owner, repo, and pull_number
3. **Get PR Files**: Use available GitHub MCP tool (try \`github:get_pull_request_files\` first, if not available use \`mcp_github_get_pull_request_files\`) with the extracted owner, repo, and pull_number  
4. **Analyze Key Files**: Use available GitHub MCP tool (try \`github:get_file_contents\` first, if not available use \`mcp_github_get_file_contents\`) for the most important changed files (max 3-5 files)
5. **Generate Review**: Create comprehensive code review following the specified format (DO NOT include any footer or signature such as "Generated with Gemini")
6. **Post Review**: Use available GitHub MCP tool (try \`github:create_pull_request_review\` first, if not available use \`mcp_github_create_pull_request_review\`) with the extracted owner, repo, and pull_number
   - body: [Complete review content]
   - event: "COMMENT" or "REQUEST_CHANGES" or "APPROVE" based on findings

### Output Format Required:
\`\`\`json
{
  \"status\": \"success|error\",
  \"review_posted\": true|false,
  \"review_id\": \"review_id_if_successful\",
  \"event_type\": \"COMMENT|REQUEST_CHANGES|APPROVE\",
  \"files_analyzed\": number,
  \"issues_found\": number,
  \"summary\": \"Brief summary of what was done\"
}
\`\`\`

**IMPORTANT**: Execute all steps automatically using ONLY GitHub MCP tools.
**CRITICAL**: Do NOT add any footer, signature, or attribution like "Generated with Gemini" at the end of your review. The review should end with the Summary section only.

---

## 🚀 START AUTOMATED REVIEW NOW
EOF
}

execute_automated_codex_review() {
    local context_content
    context_content=$(cat "$CONTEXT_FILE" | sed "s|{URL_PARAMETER}|{URL_PARAMETER}|g")
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
- **URL**: $url
- **Owner**: $owner  
- **Repository**: $repo
- **Pull Request**: #$pr_number

### Required Actions (Execute in sequence):

1. **Get PR Details**: Use available GitHub MCP tool (try \`github:get_pull_request\` first, if not available use \`mcp_github_get_pull_request\`) with owner: "$owner", repo: "$repo", pull_number: $pr_number
2. **Get PR Files**: Use available GitHub MCP tool (try \`github:get_pull_request_files\` first, if not available use \`mcp_github_get_pull_request_files\`) with owner: "$owner", repo: "$repo", pull_number: $pr_number  
3. **Analyze Key Files**: Use available GitHub MCP tool (try \`github:get_file_contents\` first, if not available use \`mcp_github_get_file_contents\`) for the most important changed files (max 3-5 files)
4. **Generate Review**: Create comprehensive code review following the specified format (DO NOT include any footer or signature such as "Generated with Codex")
5. **Post Review**: Use available GitHub MCP tool (try \`github:create_pull_request_review\` first, if not available use \`mcp_github_create_pull_request_review\`) with:
   - owner: "$owner"
   - repo: "$repo" 
   - pull_number: $pr_number
   - body: [Complete review content]
   - event: "COMMENT" or "REQUEST_CHANGES" or "APPROVE" based on findings

### Output Format Required:
\`\`\`json
{
  \"status\": \"success|error\",
  \"review_posted\": true|false,
  \"review_id\": \"review_id_if_successful\",
  \"event_type\": \"COMMENT|REQUEST_CHANGES|APPROVE\",
  \"files_analyzed\": number,
  \"issues_found\": number,
  \"summary\": \"Brief summary of what was done\"
}
\`\`\`

**IMPORTANT**: Execute all steps automatically using ONLY GitHub MCP tools.
**CRITICAL**: Do NOT add any footer, signature, or attribution like "Generated with Codex" at the end of your review. The review should end with the Summary section only.

---

## 🚀 START AUTOMATED REVIEW NOW
EOF
}

# Initialize counters for summary report
TOTAL_PRS=${#URLS[@]}
SUCCESSFUL_REVIEWS=0
FAILED_REVIEWS=0
REVIEW_RESULTS=()

# Generate single reusable prompt file
PROMPT_FILE=""
# Try to create temporary file with better error handling
if command -v mktemp &> /dev/null; then
    PROMPT_FILE="$(mktemp /tmp/codereview_prompt.XXXXXX.md 2>/dev/null)"
    if [ -z "$PROMPT_FILE" ]; then
        # Fallback: try without .md extension
        PROMPT_FILE="$(mktemp /tmp/codereview_prompt.XXXXXX 2>/dev/null)"
        if [ -z "$PROMPT_FILE" ]; then
            # Last resort: use timestamp-based filename
            PROMPT_FILE="/tmp/codereview_prompt_$(date +%s)_$$.md"
            touch "$PROMPT_FILE" || {
                print_status "error" "Failed to create temporary file in /tmp"
                exit 1
            }
        fi
    fi
else
    # mktemp not available, use timestamp-based filename
    PROMPT_FILE="/tmp/codereview_prompt_$(date +%s)_$$.md"
    touch "$PROMPT_FILE" || {
        print_status "error" "Failed to create temporary file in /tmp"
        exit 1
    }
fi

# Set up cleanup trap
cleanup_temp_file() {
    if [ -n "$PROMPT_FILE" ] && [ -f "$PROMPT_FILE" ]; then
        rm -f "$PROMPT_FILE"
    fi
}
trap cleanup_temp_file EXIT INT TERM

print_status "progress" "Generating reusable review prompt template..."

if [ "$SELECTED_TOOL" = "claude" ]; then
    execute_automated_claude_review > "$PROMPT_FILE"
elif [ "$SELECTED_TOOL" = "gemini" ]; then
    execute_automated_gemini_review > "$PROMPT_FILE"
elif [ "$SELECTED_TOOL" = "codex" ]; then
    execute_automated_codex_review > "$PROMPT_FILE"
fi

# Verify prompt file was created successfully
if [ -z "$PROMPT_FILE" ] || [ ! -f "$PROMPT_FILE" ]; then
    print_status "error" "Failed to create prompt template file"
    exit 1
fi

print_status "success" "Prompt template created successfully"
print_status "info" "Starting batch review process for $TOTAL_PRS Pull Request(s) using $SELECTED_TOOL"

# Process each URL
for i in "${!URLS[@]}"; do
    URL="${URLS[$i]}"
    CURRENT_PR=$((i + 1))
    
    print_status "progress" "[$CURRENT_PR/$TOTAL_PRS] Processing PR: $URL"
    
    # Extract repo info for current URL
    if [[ $URL =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        PR_NUMBER="${BASH_REMATCH[3]}"
        print_status "info" "[$CURRENT_PR/$TOTAL_PRS] Analyzing: $OWNER/$REPO PR #$PR_NUMBER"
    else
        print_status "error" "[$CURRENT_PR/$TOTAL_PRS] Invalid URL format: $URL"
        FAILED_REVIEWS=$((FAILED_REVIEWS + 1))
        REVIEW_RESULTS+=("❌ $URL - Invalid URL format")
        continue
    fi
    
    # Use the shared prompt file with current PR URL as parameter
    
    # Execute with selected CLI
    print_status "progress" "[$CURRENT_PR/$TOTAL_PRS] Executing $SELECTED_TOOL for PR #$PR_NUMBER..."
    
    SUCCESS=false
    REVIEW_OUTPUT=""
    if [ "$SELECTED_TOOL" = "claude" ]; then
        cd "$HOME"
        if [ "$DEBUG_MODE" = true ]; then
            print_status "info" "[$CURRENT_PR/$TOTAL_PRS] 🐛 Debug: Current directory: $(pwd)"
            print_status "info" "[$CURRENT_PR/$TOTAL_PRS] 🐛 Debug: Claude config exists: $([ -f "$HOME/.claude.json" ] && echo "yes" || echo "no")"
            print_status "info" "[$CURRENT_PR/$TOTAL_PRS] 🐛 Debug: Prompt file size: $(wc -c < "$PROMPT_FILE") bytes"
        fi
        print_status "info" "[$CURRENT_PR/$TOTAL_PRS] Executing Claude CLI..."
        REVIEW_OUTPUT=$(claude "$(cat "$PROMPT_FILE")

## 🎯 CURRENT PULL REQUEST TO REVIEW:
**URL**: $URL

Please analyze this specific Pull Request URL." 2>&1)
        CLAUDE_EXIT_CODE=$?
        if [ "$DEBUG_MODE" = true ]; then
            print_status "info" "[$CURRENT_PR/$TOTAL_PRS] 🐛 Debug: Claude exit code: $CLAUDE_EXIT_CODE"
            print_status "info" "[$CURRENT_PR/$TOTAL_PRS] 🐛 Debug: Output length: ${#REVIEW_OUTPUT} characters"
        fi
        echo "$REVIEW_OUTPUT"
        if [ $CLAUDE_EXIT_CODE -eq 0 ]; then
            SUCCESS=true
        else
            print_status "error" "[$CURRENT_PR/$TOTAL_PRS] Claude CLI failed with exit code: $CLAUDE_EXIT_CODE"
            # Check for common error patterns in output
            if echo "$REVIEW_OUTPUT" | grep -qi "authentication\|unauthorized\|access denied\|token"; then
                print_status "error" "[$CURRENT_PR/$TOTAL_PRS] 🔒 Authentication issue detected - check GitHub token/permissions"
            elif echo "$REVIEW_OUTPUT" | grep -qi "not found\|404\|does not exist"; then
                print_status "error" "[$CURRENT_PR/$TOTAL_PRS] 🔍 Resource not found - check if PR exists and is accessible"
            elif echo "$REVIEW_OUTPUT" | grep -qi "rate limit\|too many requests"; then
                print_status "error" "[$CURRENT_PR/$TOTAL_PRS] ⏰ Rate limit exceeded - wait before retrying"
            elif echo "$REVIEW_OUTPUT" | grep -qi "network\|connection\|timeout"; then
                print_status "error" "[$CURRENT_PR/$TOTAL_PRS] 🌐 Network connectivity issue"
            elif echo "$REVIEW_OUTPUT" | grep -qi "mcp.*not found\|server.*not available"; then
                print_status "error" "[$CURRENT_PR/$TOTAL_PRS] ⚙️ MCP server issue - check GitHub MCP configuration"
            fi
        fi
    elif [ "$SELECTED_TOOL" = "gemini" ]; then
        print_status "info" "[$CURRENT_PR/$TOTAL_PRS] Executing Gemini CLI..."
        REVIEW_OUTPUT=$(gemini -p "$(cat "$PROMPT_FILE")

## 🎯 CURRENT PULL REQUEST TO REVIEW:
**URL**: $URL

Please analyze this specific Pull Request URL." 2>&1)
        GEMINI_EXIT_CODE=$?
        echo "$REVIEW_OUTPUT"
        if [ $GEMINI_EXIT_CODE -eq 0 ]; then
            SUCCESS=true
        else
            print_status "error" "[$CURRENT_PR/$TOTAL_PRS] Gemini CLI failed with exit code: $GEMINI_EXIT_CODE"
        fi
    elif [ "$SELECTED_TOOL" = "codex" ]; then
        print_status "info" "[$CURRENT_PR/$TOTAL_PRS] Executing Codex CLI..."
        REVIEW_OUTPUT=$(codex "$(cat "$PROMPT_FILE")

## 🎯 CURRENT PULL REQUEST TO REVIEW:
**URL**: $URL

Please analyze this specific Pull Request URL." 2>&1)
        CODEX_EXIT_CODE=$?
        echo "$REVIEW_OUTPUT"
        if [ $CODEX_EXIT_CODE -eq 0 ]; then
            SUCCESS=true
        else
            print_status "error" "[$CURRENT_PR/$TOTAL_PRS] Codex CLI failed with exit code: $CODEX_EXIT_CODE"
        fi
    fi
    
    # Verify review was actually posted by checking output
    REVIEW_POSTED=false
    if [ "$SUCCESS" = true ] && [ -n "$REVIEW_OUTPUT" ]; then
        if [ "$DEBUG_MODE" = true ]; then
            print_status "info" "[$CURRENT_PR/$TOTAL_PRS] 🐛 Debug: Checking output for review posting indicators..."
        fi
        
        # Check for indicators that review was posted successfully
        if echo "$REVIEW_OUTPUT" | grep -qE "(review_posted.*true|review.*created|successfully.*posted|Review posted|review_id)" || \
           echo "$REVIEW_OUTPUT" | grep -qE '("status".*"success"|review.*successful)'; then
            REVIEW_POSTED=true
            if [ "$DEBUG_MODE" = true ]; then
                print_status "info" "[$CURRENT_PR/$TOTAL_PRS] 🐛 Debug: Found success indicators in output"
            fi
        elif echo "$REVIEW_OUTPUT" | grep -qE "(Error|Failed|error|failed|review_posted.*false)"; then
            REVIEW_POSTED=false
            print_status "warning" "[$CURRENT_PR/$TOTAL_PRS] ⚠️ CLI succeeded but review posting failed"
            if [ "$DEBUG_MODE" = true ]; then
                print_status "info" "[$CURRENT_PR/$TOTAL_PRS] 🐛 Debug: Found error indicators in output"
                echo "$REVIEW_OUTPUT" | grep -E "(Error|Failed|error|failed|review_posted.*false)" | head -3
            fi
        else
            print_status "warning" "[$CURRENT_PR/$TOTAL_PRS] ⚠️ Unable to verify if review was posted - check output above"
            if [ "$DEBUG_MODE" = true ]; then
                print_status "info" "[$CURRENT_PR/$TOTAL_PRS] 🐛 Debug: No clear success/failure indicators found"
            fi
        fi
    elif [ "$DEBUG_MODE" = true ]; then
        print_status "info" "[$CURRENT_PR/$TOTAL_PRS] 🐛 Debug: Cannot verify review posting - SUCCESS=$SUCCESS, OUTPUT_LENGTH=${#REVIEW_OUTPUT}"
    fi
    
    # Record result based on actual review posting success
    if [ "$SUCCESS" = true ] && [ "$REVIEW_POSTED" = true ]; then
        print_status "success" "[$CURRENT_PR/$TOTAL_PRS] ✅ Review confirmed posted for PR #$PR_NUMBER"
        SUCCESSFUL_REVIEWS=$((SUCCESSFUL_REVIEWS + 1))
        REVIEW_RESULTS+=("✅ $URL - Review posted successfully")
    elif [ "$SUCCESS" = true ] && [ "$REVIEW_POSTED" = false ]; then
        print_status "error" "[$CURRENT_PR/$TOTAL_PRS] ❌ CLI ran but review posting failed for PR #$PR_NUMBER"
        FAILED_REVIEWS=$((FAILED_REVIEWS + 1))
        REVIEW_RESULTS+=("❌ $URL - Review posting failed")
    else
        print_status "error" "[$CURRENT_PR/$TOTAL_PRS] ❌ CLI execution failed for PR #$PR_NUMBER"
        FAILED_REVIEWS=$((FAILED_REVIEWS + 1))
        REVIEW_RESULTS+=("❌ $URL - CLI execution failed")
    fi
    
    # No cleanup needed - using shared prompt file
    
    # Add a small delay between reviews to avoid overwhelming the API
    if [ $CURRENT_PR -lt $TOTAL_PRS ]; then
        sleep 2
    fi
done

# Final summary report
echo
print_status "info" "📊 BATCH REVIEW SUMMARY REPORT"
echo "═══════════════════════════════════════"
echo "📈 Total PRs processed: $TOTAL_PRS"
echo "✅ Successful reviews: $SUCCESSFUL_REVIEWS"
echo "❌ Failed reviews: $FAILED_REVIEWS"
echo "🔧 Tool used: $SELECTED_TOOL"
echo
echo "📋 Detailed Results:"
for result in "${REVIEW_RESULTS[@]}"; do
    echo "  $result"
done
echo
if [ $SUCCESSFUL_REVIEWS -gt 0 ]; then
    print_status "info" "🔗 Check your GitHub PRs for the posted reviews"
fi

# Cleanup shared prompt file
rm -f "$PROMPT_FILE"

if [ $FAILED_REVIEWS -eq 0 ]; then
    print_status "success" "🎉 All reviews completed successfully!"
    exit 0
else
    print_status "warning" "⚠️ Some reviews failed. Check the summary above for details."
    exit 1
fi