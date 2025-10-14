/**
 * Configuration management for CodeReview API
 */

export const CONFIG = {
  // Server configuration
  PORT: Number(Deno.env.get("PORT") ?? "8787"),
  HOST: Deno.env.get("HOST") ?? "localhost",
  
  // Script configuration
  SCRIPT_PATH: Deno.env.get("SCRIPT_PATH") ?? "./codereview.sh",
  
  // Rate limiting
  RATE_LIMIT_REQUESTS: Number(Deno.env.get("RATE_LIMIT_REQUESTS") ?? "10"),
  RATE_LIMIT_WINDOW_MS: Number(Deno.env.get("RATE_LIMIT_WINDOW_MS") ?? "60000"),
  
  // Request limits
  MAX_URLS: Number(Deno.env.get("MAX_URLS") ?? "10"),
  TIMEOUT_MS: Number(Deno.env.get("TIMEOUT_MS") ?? "300000"), // 5 minutes
  
  // Environment
  NODE_ENV: Deno.env.get("NODE_ENV") ?? "development",
  LOG_LEVEL: Deno.env.get("LOG_LEVEL") ?? "info",
  
  // CORS
  CORS_ORIGINS: Deno.env.get("CORS_ORIGINS")?.split(",") ?? ["*"],
  
  // Health check
  VERSION: "2.0.0",
} as const;

// Validate configuration
export function validateConfig(): void {
  if (CONFIG.PORT < 1 || CONFIG.PORT > 65535) {
    throw new Error(`Invalid PORT: ${CONFIG.PORT}. Must be between 1 and 65535.`);
  }
  
  if (CONFIG.MAX_URLS < 1 || CONFIG.MAX_URLS > 50) {
    throw new Error(`Invalid MAX_URLS: ${CONFIG.MAX_URLS}. Must be between 1 and 50.`);
  }
  
  if (CONFIG.TIMEOUT_MS < 1000) {
    throw new Error(`Invalid TIMEOUT_MS: ${CONFIG.TIMEOUT_MS}. Must be at least 1000ms.`);
  }
}
