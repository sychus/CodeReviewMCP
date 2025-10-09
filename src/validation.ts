/**
 * Request validation using Zod
 */

import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

// GitHub PR URL schema
const GitHubPRSchema = z.string().url().refine(
  (url) => {
    const regex = /^https:\/\/github\.com\/[\w.-]+\/[\w.-]+\/pull\/\d+$/;
    return regex.test(url);
  },
  { message: "Must be a valid GitHub PR URL (https://github.com/owner/repo/pull/123)" }
);

// Review arguments schema
export const ReviewArgsSchema = z.object({
  context_file: z.string()
    .min(1, "Context file cannot be empty")
    .regex(/\.(md|txt)$/i, "Context file must be .md or .txt")
    .optional()
    .default("review.md"),
  urls: z.array(GitHubPRSchema)
    .min(1, "At least one URL is required")
    .max(10, "Maximum 10 URLs allowed"),
  prefer_cli: z.enum(["claude", "gemini", "codex"]).optional(),
  debug: z.boolean().optional().default(false),
});

// Natural language request schema
export const NLRequestSchema = z.object({
  query: z.string()
    .min(5, "Query must be at least 5 characters")
    .max(1000, "Query must be less than 1000 characters"),
});

// Health check response schema
export const HealthResponseSchema = z.object({
  status: z.enum(["ok", "degraded", "error"]),
  timestamp: z.string(),
  server: z.object({
    port: z.number(),
    uptime: z.number(),
    version: z.string(),
  }),
  dependencies: z.object({
    script: z.object({
      path: z.string(),
      exists: z.boolean(),
      executable: z.boolean(),
    }),
  }),
});

export type ReviewArgs = z.infer<typeof ReviewArgsSchema>;
export type NLRequest = z.infer<typeof NLRequestSchema>;
export type HealthResponse = z.infer<typeof HealthResponseSchema>;

/**
 * Validation error formatter
 */
export function formatValidationError(error: z.ZodError): string {
  const issues = error.issues.map(issue => 
    `${issue.path.join('.')}: ${issue.message}`
  ).join('; ');
  
  return `Validation failed: ${issues}`;
}

/**
 * Safe validation with error handling
 */
export function validateReviewArgs(data: unknown): { success: true; data: ReviewArgs } | { success: false; error: string } {
  try {
    const validated = ReviewArgsSchema.parse(data);
    return { success: true, data: validated };
  } catch (error) {
    if (error instanceof z.ZodError) {
      return { success: false, error: formatValidationError(error) };
    }
    return { success: false, error: "Invalid data format" };
  }
}

export function validateNLRequest(data: unknown): { success: true; data: NLRequest } | { success: false; error: string } {
  try {
    const validated = NLRequestSchema.parse(data);
    return { success: true, data: validated };
  } catch (error) {
    if (error instanceof z.ZodError) {
      return { success: false, error: formatValidationError(error) };
    }
    return { success: false, error: "Invalid data format" };
  }
}
