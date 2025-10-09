/**
 * Enhanced type definitions for CodeReview API
 */

export interface ReviewArgs {
  context_file?: string;     // by default "review.md"
  urls: string[];            // required GitHub PR URLs
  prefer_cli?: "claude" | "gemini" | "codex";
  debug?: boolean;
}

export interface NLRequest {
  query: string;             // natural language text
}

export interface RunResult {
  ok: boolean;
  code: number;
  out: string;
  err?: string;
  duration_ms?: number;      // execution duration
}

export interface APIResponse<T = unknown> {
  status: "success" | "error";
  timestamp: string;
  request_id?: string;
  data?: T;
  error?: string;
}

export interface ReviewResponse extends RunResult {
  request_id: string;
  parsed_args?: ReviewArgs;
  query?: string;
}

export interface HealthStatus {
  status: "ok" | "degraded" | "error";
  timestamp: string;
  server: {
    port: number;
    uptime: number;
    version: string;
  };
  dependencies: {
    script: {
      path: string;
      exists: boolean;
      executable: boolean;
    };
  };
}

// Re-export validation types
export type { ReviewArgs as ValidatedReviewArgs } from "./validation.ts";
export type { NLRequest as ValidatedNLRequest } from "./validation.ts";
export type { HealthResponse } from "./validation.ts";
  