/**
 * Enhanced Natural Language Parser for review requests
 */

import type { ReviewArgs } from "../types.ts";
import { Logger } from "../logger.ts";

/**
 * Enhanced natural language parser with more patterns and better detection
 */
export function parseNL(text: string): ReviewArgs {
  const res: ReviewArgs = { 
    context_file: "review.md", 
    urls: [], 
    debug: false 
  };

  Logger.debug("Parsing natural language input", { text_length: text.length });

  // Pattern 1: org/repo + "pr #1, #2" or "prs 1 2"
  const orgRepo = text.match(/([\w-]+)\/([\w.-]+)/);
  const batchPatterns = [
    /\bprs?\b\s+([#\d,\s]+)/i,
    /pull\s*requests?\s+([#\d,\s]+)/i,
    /revisar\s+prs?\s+([#\d,\s]+)/i,
    /review\s+prs?\s+([#\d,\s]+)/i,
    /check\s+prs?\s+([#\d,\s]+)/i,
  ];

  if (orgRepo) {
    const [, org, repo] = orgRepo;
    
    for (const pattern of batchPatterns) {
      const match = text.match(pattern);
      if (match) {
        const list = match[1];
        const prs = list.split(/[,\s]+/)
          .filter(Boolean)
          .map(n => n.replace(/^#/, ""))
          .filter(n => /^\d+$/.test(n)); // Only valid numbers
          
        res.urls.push(
          ...prs.map(n => `https://github.com/${org}/${repo}/pull/${n}`)
        );
        Logger.debug("Found batch PR pattern", { org, repo, prs });
        break;
      }
    }
  }

  // Pattern 2: Explicit URLs
  const urlRegex = /https:\/\/github\.com\/[\w.-]+\/[\w.-]+\/pull\/\d+/gi;
  const urlMatches = text.match(urlRegex) ?? [];
  res.urls.push(...urlMatches);
  
  if (urlMatches.length > 0) {
    Logger.debug("Found explicit URLs", { count: urlMatches.length });
  }

  // Pattern 3: Context/template file patterns
  const contextPatterns = [
    /\b(?:plantilla|template)\s+(\S+)/i,
    /\b(?:contexto|context)\s+(\S+)/i,
    /\b(?:usando|using|con|with)\s+(\S+\.md)\b/i,
    /\b(?:archivo|file)\s+(\S+\.(?:md|txt))\b/i,
    /\-(?:f|file|template)\s+(\S+)/i,
  ];

  for (const pattern of contextPatterns) {
    const match = text.match(pattern);
    if (match) {
      res.context_file = match[1];
      Logger.debug("Found context file pattern", { file: match[1] });
      break;
    }
  }

  // Pattern 4: CLI preference patterns
  const cliPatterns = {
    claude: [
      /\b(?:claude|anthropic)\b/i,
      /\buse\s+claude\b/i,
      /\bcon\s+claude\b/i,
    ],
    gemini: [
      /\b(?:gemini|google|bard)\b/i,
      /\buse\s+gemini\b/i,
      /\bcon\s+gemini\b/i,
    ],
    codex: [
      /\b(?:codex|openai|gpt)\b/i,
      /\buse\s+codex\b/i,
      /\bcon\s+codex\b/i,
    ],
  };

  for (const [cli, patterns] of Object.entries(cliPatterns)) {
    if (patterns.some(pattern => pattern.test(text))) {
      res.prefer_cli = cli as "claude" | "gemini" | "codex";
      Logger.debug("Found CLI preference", { cli });
      break;
    }
  }

  // Pattern 5: Debug mode patterns
  const debugPatterns = [
    /\b(?:debug|verbose|--debug|-v)\b/i,
    /\bcon\s+debug\b/i,
    /\bmodo\s+debug\b/i,
  ];

  if (debugPatterns.some(pattern => pattern.test(text))) {
    res.debug = true;
    Logger.debug("Debug mode enabled from NL input");
  }

  // Pattern 6: Multiple repository patterns
  const multiRepoPattern = /github\.com\/([\w.-]+)\/([\w.-]+)/gi;
  const repoMatches = [...text.matchAll(multiRepoPattern)];
  
  if (repoMatches.length > 1) {
    Logger.debug("Found multiple repositories", { 
      repos: repoMatches.map(m => `${m[1]}/${m[2]}`) 
    });
  }

  // Deduplicate URLs
  res.urls = Array.from(new Set(res.urls));

  // Validate that we found at least some URLs
  if (res.urls.length === 0) {
    Logger.warn("No valid GitHub PR URLs found in input", { 
      text: text.substring(0, 100) + "..." 
    });
  }

  Logger.debug("NL parsing complete", {
    urls_found: res.urls.length,
    context_file: res.context_file,
    prefer_cli: res.prefer_cli,
    debug: res.debug,
  });

  return res;
}

/**
 * Extract repository info from GitHub URL
 */
export function extractRepoInfo(url: string): { 
  owner: string; 
  repo: string; 
  pr: number;
  url: string;
} | null {
  const match = url.match(/github\.com\/([\w.-]+)\/([\w.-]+)\/pull\/(\d+)/);
  if (!match) return null;
  
  return {
    owner: match[1],
    repo: match[2],
    pr: parseInt(match[3], 10),
    url,
  };
}

/**
 * Validate natural language input quality
 */
export function validateNLInput(text: string): {
  isValid: boolean;
  score: number;
  issues: string[];
} {
  const issues: string[] = [];
  let score = 0;

  // Check length
  if (text.length < 10) {
    issues.push("Input is too short");
  } else if (text.length > 1000) {
    issues.push("Input is too long");
  } else {
    score += 2;
  }

  // Check for GitHub mentions
  if (/github/i.test(text)) score += 3;
  if (/pull\s*request|pr\b/i.test(text)) score += 3;

  // Check for action words
  if (/review|revisar|analyze|check/i.test(text)) score += 2;

  // Check for URL patterns
  if (/https?:\/\//.test(text)) score += 2;

  // Check for repository patterns
  if (/[\w-]+\/[\w.-]+/.test(text)) score += 2;

  const isValid = score >= 5 && issues.length === 0;

  return { isValid, score, issues };
}
